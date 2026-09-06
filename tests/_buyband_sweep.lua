-- Heavy corpus sweep for tests/test_buyband_hp_band.lua, run as a SUBPROCESS: a
-- full-corpus drive that rebuilds jmz_func once per hero-frame must not run on
-- run_tests.lua's long-lived heap.  The leading underscore keeps run_tests.lua
-- from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  Two numbers in this tree disagree about when a hurt bot is
-- hurt.  J.ShouldStayAndRegen is PROMOTED -- live in every turbo game -- and its
-- band runs to 0.75 HP: that is this tree's own definition of "hurt enough that
-- going home is on the table".  J.IsFieldRegenSituation, which decides whether the
-- FIELD alternative is offered at all, stops at 0.55.  Between those two numbers a
-- hurt, safe, empty-handed bot is released to go home while the id whose whole job
-- is "buy the salve instead" is structurally silent.  'buyband' is the standalone
-- lever for that band.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR IS `flips_buyband`, AND WHY IT IS NONZERO.
-- The tempting edit -- pass a gated ceiling from inside J.ShouldFieldBuyRegen --
-- would sit BEHIND that function's own `IsSoakCandidate('fieldbuy')` first line,
-- so the new id could only ever act with 'fieldbuy' also armed: two ids on one
-- path, every site reading clean, and any single-arm isolation wave reading a
-- correct zero (the second form of the 'pullcad' trap, GH #542).  This lever is
-- the standalone form, and `flips_buyband` -- driven with NOTHING ELSE armed --
-- is what proves a single-arm wave can see it.  A zero there means the lever is
-- unbuyable one arm at a time and the whole design failed, not that the corpus is
-- thin; `hurt_domain` is the independent prefix walk that tells those two apart.
--
-- ⭐⭐ THE COMPARISON IS DRIVEN, NOT SHADOWED.  Every answer comes from the shipped
-- functions with J.IsSoakCandidate stubbed.  Nothing here re-implements the
-- decision.  The prefix buckets ARE evaluated separately -- that is what makes
-- "the clause was reached" and "the clause vetoed" two different numbers -- and
-- the two routes are cross-checked: `flips_buyband` (driven, from the call-site
-- predicate pair's own return values) and `hurt_domain` (bucketed, from the prefix
-- walk) must be EQUAL, and the test asserts that.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  The call site is an OR of two
-- predicates, so arming can only add TRUEs.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE; it must be 0, and the test asserts it.
-- `overlap_buy_hurt` counts frames where both arms answer TRUE; the domains are
-- disjoint by construction (<= 0.55 against > 0.55), so it must be 0 as well --
-- neither id can ever be credited with the other's frames.
--
-- ⚠️ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.  It measures a
-- PURCHASE PREDICATE turning true, not a trip home being cancelled and not a salve
-- being bought: the nine engine clauses guarding the actual
-- ActionImmediate_PurchaseItem (stock count, gold, stash, courier distance, empty
-- slot) are not readable from a fixture, and gold is not networked into a .dem at
-- all (GH #495).  `WIRE_*` below asserts the wiring exists in
-- item_purchase_generic.lua; nothing here asserts the purchase happens.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac>
--       one live frame where the call-site predicate flips false -> true under
--       'buyband' armed ALONE
--   N <fixture> <hero> <hp_frac>
--       one live frame that reaches J.ShouldStayAndRegen's supply clause, is
--       vetoed there carrying nothing drinkable, and is kept out of
--       J.IsFieldRegenSituation BY THE 0.55 CEILING AND NOTHING ELSE
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local BUY = 'bots/item_purchase_generic.lua'

local function read_file(path)
    local f = assert(io.open(path, 'r'), path .. ' is not readable')
    local s = f:read('*a')
    f:close()
    return s
end

local function block(src, header)
    local at = src:find(header, 1, true)
    if at == nil then return nil end
    local stop = src:find('\nfunction ', at + 10) or #src
    return src:sub(at, stop)
end

-- Every structural fact below is a claim about CODE, and this lever ships with a
-- long comment naming J.IsSoakCandidate, the sibling ids, both constants and the
-- call site in prose.  Reading the raw block would let the COMMENT satisfy the
-- assertions (the §EN mistake, and the M15 near-miss of the 'staybottle' round).
local function strip_comments(s)
    if s == nil then return nil end
    return (s:gsub('%-%-[^\n]*', ''))
end

local G = {}
local src = read_file(JMZ)
local sit = strip_comments(block(src, 'function J.IsFieldRegenSituation( bot'))
local buy = strip_comments(block(src, 'function J.ShouldFieldBuyRegen( bot )'))
local hurt = strip_comments(block(src, 'function J.ShouldFieldBuyRegenHurt( bot )'))
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
G.SIT = sit and 1 or 0
G.BUY = buy and 1 or 0
G.HURT = hurt and 1 or 0
G.STAY = stay and 1 or 0
-- Did the stripping actually HAPPEN?  Asserted as its own fact rather than left to
-- be implied by some count coming out at the expected number.  It was implied once
-- ('staybag' round, M5): an exact id total was the only thing catching the "stop
-- stripping" mutant, and relaxing that total for an unrelated and correct reason
-- took the mutant's only detector with it.
G.SIT_STRIPPED = (sit and not sit:find('--', 1, true)) and 1 or 0
G.HURT_STRIPPED = (hurt and not hurt:find('--', 1, true)) and 1 or 0
G.STAY_STRIPPED = (stay and not stay:find('--', 1, true)) and 1 or 0

-- The gate, and the 'pullcad' invariant.  The trap is TWO IDS IN ONE CONDITION;
-- the per-condition maximum is the invariant, the per-function total is not.
G.HURT_SOAKID = (hurt and hurt:find("J.IsSoakCandidate( 'buyband' )", 1, true))
    and 1 or 0
local function count_ids(s)
    local n = 0
    if s then for _ in s:gmatch('IsSoakCandidate') do n = n + 1 end end
    return n
end
local function max_ids_per_cond(s)
    local nMax = 0
    if s then
        for cond in s:gmatch('if(.-)then') do
            local n = 0
            for _ in cond:gmatch('IsSoakCandidate') do n = n + 1 end
            if n > nMax then nMax = n end
        end
    end
    return nMax
end
G.HURT_NIDS = count_ids(hurt)
G.HURT_IDS_MAX_PER_COND = max_ids_per_cond(hurt)
-- The shared predicate must stay UNGATED-for-this-lever: its only id is the
-- pre-existing 'fieldcreep'.  A gate here would move 'stayfield', 'stayfield2' and
-- 'fieldbuy' with one arm -- the 'lanefix' bundle shape this design avoids.
G.SIT_NIDS = count_ids(sit)
G.SIT_HAS_BUYBAND = (sit and sit:find('buyband', 1, true)) and 1 or 0

-- The two band constants, parsed out of the two functions that already own them,
-- so "these are not new tuned numbers" is checked rather than asserted in prose.
G.STAY_HP_HI = stay and tonumber(stay:match('nHP > ([%d%.]+)')) or -1
G.SIT_HP_HI = sit and tonumber(sit:match('nHP > ([%d%.]+)')) or -1
G.STAY_HP_LO = stay and tonumber(stay:match('nHP < ([%d%.]+)')) or -1
G.SIT_HP_LO = sit and tonumber(sit:match('nHP < ([%d%.]+)')) or -1
G.HURT_FLOOR = hurt and tonumber(hurt:match('nHP <= ([%d%.]+)')) or -1
G.HURT_CEIL = hurt and tonumber(hurt:match('nHP > ([%d%.]+)')) or -1
G.HURT_HP_LO = hurt and tonumber(hurt:match('nHP < ([%d%.]+)')) or -1

-- ⭐ THE DRIFT GUARD, and it is the price of duplicating three clauses instead of
-- calling the sibling.  Each surroundings constant is parsed from BOTH bodies; the
-- test asserts the two copies are equal, so the day either moves this file goes
-- red instead of the lever quietly measuring a different situation than the one
-- its comment describes.
G.SIT_RING = sit and tonumber(sit:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.HURT_RING = hurt and tonumber(hurt:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.SIT_ATTR_RADIUS =
    sit and tonumber(sit:match('GetNearbyHeroes%( bot, 3000')) and 3000
    or (sit and sit:find('GetNearbyHeroes( bot, 3000, true', 1, true) and 3000 or -1)
G.HURT_ATTR_RADIUS =
    hurt and hurt:find('GetNearbyHeroes( bot, 3000, true', 1, true) and 3000 or -1
G.SIT_TOWER = sit and tonumber(sit:match('GetNearbyTowers%( (%d+), true')) or -1
G.HURT_TOWER = hurt and tonumber(hurt:match('GetNearbyTowers%( (%d+), true')) or -1
G.SIT_ATTR_WINDOW =
    sit and tonumber(sit:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.HURT_ATTR_WINDOW =
    hurt and tonumber(hurt:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.STAY_CHASE_WINDOW =
    stay and tonumber(stay:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.STAY_RING = stay and tonumber(stay:match('GetNearbyHeroes%( bot, (%d+), true')) or -1

-- The shipped predicate is UNTOUCHED by this lever, and that is the claim the
-- seven-file re-baseline was reverted to keep true.  Counted off the stripped
-- source so a comment can neither create nor hide a call: every call site still
-- passes exactly one argument, and there are no two-argument calls at all.
-- The DEFINITION is subtracted rather than left in the total: `function
-- J.IsFieldRegenSituation( bot )` matches the call pattern itself, so an
-- uncorrected count reads 3 for a tree with exactly two CALLERS -- a number that
-- looks like a third caller appearing out of nowhere.
local src_stripped = strip_comments(src)
local nCalls1, nCalls2, nDefs = 0, 0, 0
for _ in src_stripped:gmatch('IsFieldRegenSituation%( bot %)') do
    nCalls1 = nCalls1 + 1
end
for _ in src_stripped:gmatch('IsFieldRegenSituation%( bot, ') do
    nCalls2 = nCalls2 + 1
end
for _ in src_stripped:gmatch('function J%.IsFieldRegenSituation%( bot %)') do
    nDefs = nDefs + 1
end
G.SIT_DEFS = nDefs
G.SIT_CALLS_1ARG = nCalls1 - nDefs
G.SIT_CALLS_2ARG = nCalls2
-- ...and this lever does not call it at all: it repeats the clauses instead.
G.HURT_CALLS_SIT =
    (hurt and hurt:find('IsFieldRegenSituation', 1, true)) and 1 or 0
-- The 'fieldcreep' veto is the one clause NOT copied (honest bound (4) on the
-- lever): naming another candidate's id here would freeze this clause FALSE the
-- day that id is promoted.  Asserted from both sides -- it is still in the
-- sibling, and it is still absent here.
G.SIT_HAS_FIELDCREEP =
    (sit and sit:find("J.IsSoakCandidate( 'fieldcreep' )", 1, true)) and 1 or 0
G.HURT_HAS_FIELDCREEP =
    (hurt and hurt:find('fieldcreep', 1, true)) and 1 or 0
-- ...and the ONLY two-argument call site is this lever's own body.
local nHurt2 = 0
if hurt then
    for _ in hurt:gmatch('IsFieldRegenSituation%( bot, ') do nHurt2 = nHurt2 + 1 end
end
G.HURT_CALLS_2ARG = nHurt2

-- The wiring.  The behaviour is a PURCHASE, and a fixture cannot reach the engine
-- clauses that guard it, so the one thing that can be checked here is that the
-- predicate is actually consulted at the purchase site -- and that it is consulted
-- as an OR arm ALONGSIDE 'fieldbuy', not in place of it.
local buysrc = strip_comments(read_file(BUY))
G.WIRE_HURT = buysrc:find('J.ShouldFieldBuyRegenHurt(bot)', 1, true) and 1 or 0
G.WIRE_BUY = buysrc:find('J.ShouldFieldBuyRegen(bot)', 1, true) and 1 or 0
G.WIRE_OR = buysrc:find(
    'if ( J.ShouldFieldBuyRegen(bot) or J.ShouldFieldBuyRegenHurt(bot) )',
    1, true) and 1 or 0
G.WIRE_PURCHASES_FLASK =
    buysrc:find("ActionImmediate_PurchaseItem('item_flask')", 1, true) and 1 or 0

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
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'raises', 'stay_reach',
    'stay_blocked', 'blocked_main_src', 'blocked_bag_salve', 'blocked_nosrc',
    'ns_hp_le_floor', 'ns_hp_gt_floor', 'ns_ring_busy', 'ns_attr_danger',
    'ns_tower', 'ns_only_ceiling_blocks', 'band_frames', 'hurt_domain',
    'flips_buyband', 'flips_fieldbuy', 'flip_true_to_false', 'overlap_buy_hurt',
    'arm_leak', 'hurt_outside_stay_reach', 'hurt_outside_by_unattr_chase',
    'hurt_with_bag_salve', 'hurt_with_creep_damage', 'overlap_probe_runs' }) do
    rawset(c, k, 0)
end

--- What J.HasFieldRegenSource's MAIN loop can see on this frame, re-derived here
--- so "the corpus carries nothing" can never read the same as "the lever does
--- nothing".
local function main_src(bot)
    for i = 0, 5 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil then
            local sName = hItem:GetName()
            if sName == 'item_flask' or sName == 'item_tango'
                or sName == 'item_tango_single' or sName == 'item_faerie_fire'
            then
                return true
            end
            if sName == 'item_bottle'
                and (tonumber(hItem:GetCurrentCharges()) or 0) > 0
            then
                return true
            end
        end
    end
    return false
end

local function bag_salve(bot)
    for i = 6, 8 do
        local hItem = bot:GetItemInSlot(i)
        if hItem ~= nil and hItem:GetName() == 'item_flask' then return true end
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
                        return armed and sId == 'buyband'
                    end

                    local nHP = J.GetHP(bot)
                    local bTurbo = J.IsModeTurbo() and true or false
                    if bTurbo then bump('turbo') end

                    -- The call-site predicate PAIR, driven under four armings.
                    local function pred()
                        return J.ShouldFieldBuyRegen(bot)
                            or J.ShouldFieldBuyRegenHurt(bot)
                    end
                    local ok1, shipped = pcall(pred)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them all
                    -- would let any other live id move this guard's answer while
                    -- the flip is still attributed to this lever (the M8 survivor
                    -- of the 'stayattr' round).  Asserted 0 downstream; the
                    -- siblings that would silently widen the same path are named.
                    if J.IsSoakCandidate('fieldbuy')
                        or J.IsSoakCandidate('fieldsip')
                        or J.IsSoakCandidate('fieldcreep')
                        or J.IsSoakCandidate('bagsalve') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(pred)
                    armed = false
                    J.IsSoakCandidate = function(sId) return sId == 'fieldbuy' end
                    local ok3, buyonly = pcall(pred)
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'buyband'
                    end

                    if not (ok1 and ok2 and ok3) then
                        bump('raises')
                    else
                        if arm and not shipped then bump('flips_buyband') end
                        if buyonly and not shipped then bump('flips_fieldbuy') end
                        if shipped and not arm then
                            -- Must never happen: the call site ORs a new arm in,
                            -- which can only add TRUEs.  Asserted 0 downstream.
                            bump('flip_true_to_false')
                        end
                        -- Disjointness, measured rather than argued.  Both arms
                        -- answering TRUE on one frame would mean one id can be
                        -- credited with the other's behaviour.
                        do
                            J.IsSoakCandidate = function(sId)
                                return sId == 'buyband'
                            end
                            local okh, hurtonly = pcall(J.ShouldFieldBuyRegenHurt, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'fieldbuy'
                            end
                            local okb, buyarm = pcall(J.ShouldFieldBuyRegen, bot)
                            J.IsSoakCandidate = function(sId)
                                return armed and sId == 'buyband'
                            end
                            -- ⭐ The probe must PROVE it ran.  `overlap_buy_hurt`
                            -- is a claim whose whole content is a zero, and a
                            -- probe that stops driving prints the same zero as a
                            -- probe that drove 1012 frames and found nothing --
                            -- the shape GH #171 is about, and the shape the
                            -- sibling stand's M12 exists for.  This counter is
                            -- asserted equal to the live frame count downstream,
                            -- so "measured and empty" and "not measured" stop
                            -- being the same reading.
                            if okh and okb then bump('overlap_probe_runs') end
                            if okh and okb and hurtonly and buyarm then
                                bump('overlap_buy_hurt')
                            end
                        end
                    end

                    -- Independent prefix walk #1: J.ShouldStayAndRegen's own
                    -- supply clause, and the three-way split of what it vetoes.
                    -- This is the domain price -- where the 66 empty-handed frames
                    -- come from -- and it is computed WITHOUT calling this lever.
                    local okS, shipStay = pcall(J.ShouldStayAndRegen, bot)
                    local bStayReach = bTurbo
                        and nHP >= G.STAY_HP_LO and nHP <= G.STAY_HP_HI
                        and not bot:WasRecentlyDamagedByAnyHero(G.STAY_CHASE_WINDOW)
                        and #J.GetNearbyHeroes(bot, G.STAY_RING, true,
                            BOT_MODE_NONE) == 0
                    local bMain = main_src(bot)
                    local bBag = bag_salve(bot)
                    local bRingBusy = #J.GetNearbyHeroes(bot, G.SIT_RING, true,
                        BOT_MODE_NONE) > 0
                    local bAttr = false
                    if bot:WasRecentlyDamagedByAnyHero(G.STAY_CHASE_WINDOW) then
                        for _, hEnemy in pairs(J.GetNearbyHeroes(bot, 3000, true,
                            BOT_MODE_NONE)) do
                            if J.IsValidHero(hEnemy)
                                and bot:WasRecentlyDamagedByHero(hEnemy,
                                    G.STAY_CHASE_WINDOW)
                            then
                                bAttr = true
                            end
                        end
                    end
                    local bTower = #bot:GetNearbyTowers(G.SIT_TOWER, true) > 0

                    if okS and bStayReach then
                        bump('stay_reach')
                        if not shipStay then
                            bump('stay_blocked')
                            if bMain then
                                bump('blocked_main_src')
                            elseif bBag then
                                bump('blocked_bag_salve')
                            else
                                bump('blocked_nosrc')
                                if nHP <= G.SIT_HP_HI then
                                    bump('ns_hp_le_floor')
                                else
                                    bump('ns_hp_gt_floor')
                                end
                                if bRingBusy then bump('ns_ring_busy') end
                                if bAttr then bump('ns_attr_danger') end
                                if bTower then bump('ns_tower') end
                                if nHP > G.SIT_HP_HI and not bRingBusy
                                    and not bAttr and not bTower
                                then
                                    bump('ns_only_ceiling_blocks')
                                    out:write(string.format('N %s %s %.4f\n',
                                        path:match('([^/]+)%.lua$'), u.name, nHP))
                                end
                            end
                        end
                    end

                    -- Independent prefix walk #2: this lever's OWN domain, in its
                    -- own clause order, with nothing armed.  Cross-checked against
                    -- the driven `flips_buyband` above -- the two must be equal.
                    if nHP > G.SIT_HP_HI and nHP <= G.HURT_CEIL then
                        bump('band_frames')
                    end
                    if bTurbo
                        and nHP > G.HURT_FLOOR and nHP >= G.SIT_HP_LO
                        and nHP <= G.HURT_CEIL
                        and not bRingBusy and not bAttr and not bTower
                        and not bMain
                    then
                        bump('hurt_domain')
                        -- Why this lever's domain is BIGGER than the
                        -- `ns_only_ceiling_blocks` slice of the census above, named
                        -- rather than left as a difference of two totals.  That
                        -- slice is a subset of J.ShouldStayAndRegen's REACH set,
                        -- whose chase clause is the UNATTRIBUTED
                        -- WasRecentlyDamagedByAnyHero read ('stayattr' is the lever
                        -- for that, and this census does not arm it).  A frame
                        -- carrying global-ult damage from across the map never
                        -- reaches that supply clause at all, so it cannot appear in
                        -- the slice -- while this lever, which inherits
                        -- J.IsFieldRegenSituation's ATTRIBUTED read, does answer on
                        -- it.  Counted, so the gap is a measured number and not an
                        -- explanation.
                        -- The OTHER reason a domain frame can be missing from that
                        -- slice, and it is the GH #123 asymmetry showing up on the
                        -- new arm exactly as it already does on 'fieldbuy': the
                        -- census routes a backpacked salve into its own bucket
                        -- ('staybag' owns those), while this predicate -- like
                        -- J.ShouldFieldBuyRegen, whose conjunction it copies --
                        -- reads J.HasFieldRegenSource, which stops at slot 5 and so
                        -- answers "carrying nothing".  It is guarded at the call
                        -- site, not here: `bot:FindItemSlot('item_flask') < 0`
                        -- DOES see the backpack, which is why the shipped block
                        -- says so in its own comment.  Counted so that
                        -- hurt_domain == ns_only_ceiling_blocks + these two
                        -- residues is an arithmetic identity the test can check,
                        -- rather than a difference of totals nobody explains.
                        if bBag then bump('hurt_with_bag_salve') end
                        -- Honest bound (4) on the lever, as a column rather than
                        -- a promise: the ONE clause of J.IsFieldRegenSituation
                        -- this function does not copy is the gated 'fieldcreep'
                        -- veto (copying it would name another candidate's id and
                        -- freeze this clause FALSE the day that id is promoted --
                        -- the 'pullcad' trap).  So while 'fieldcreep' is armed the
                        -- two call-site arms disagree about a bot being chewed by
                        -- a camp.  This counts how wide that disagreement actually
                        -- is on the corpus.
                        if bot:WasRecentlyDamagedByCreep(G.SIT_ATTR_WINDOW) then
                            bump('hurt_with_creep_damage')
                        end
                        if not bStayReach then
                            bump('hurt_outside_stay_reach')
                            if bot:WasRecentlyDamagedByAnyHero(G.STAY_CHASE_WINDOW)
                            then
                                bump('hurt_outside_by_unattr_chase')
                            end
                        end
                        out:write(string.format('F %s %s %.4f\n',
                            path:match('([^/]+)%.lua$'), u.name, nHP))
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
