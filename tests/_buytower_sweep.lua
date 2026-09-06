-- Heavy corpus sweep for tests/test_buytower_purchase_domain.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame must
-- not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  One clause of J.IsFieldRegenSituation states its own reason
-- in its own comment, and that reason is about a consumer this lever is not:
-- `#bot:GetNearbyTowers( 1200, true ) > 0` exists so the HOLD side does not cancel
-- a local back-off from a tower ("suppressing it would leave the bot parked in
-- tower range").  The SUPPLY side cancels nothing -- it adds an OR arm to a
-- purchase -- so on the buy arms that clause vetoes for a reason that has nothing
-- to do with buying, and a hurt, empty-handed bot near an enemy tower is left with
-- no salve and sent home: the trip owner priority P2 forbids.  'buytower' is the
-- standalone lever for exactly those frames.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR IS `flips_buytower`, AND WHY IT IS NONZERO.
-- The lever must be visible to a SINGLE-ARM isolation wave.  Putting the clause
-- behind J.ShouldFieldBuyRegen's own `IsSoakCandidate('fieldbuy')` first line, or
-- behind J.ShouldFieldBuyRegenHurt's `'buyband'` one, would make the new id
-- unreachable unless the sibling were armed too: two ids on one PATH, every site
-- reading clean, and any single-arm wave reading a CORRECT zero (the second form
-- of the 'pullcad' trap, GH #542).  `flips_buytower` is driven with nothing else
-- armed.  A zero there means the design failed, not that the corpus is thin --
-- `tower_domain`, the independent prefix walk, is what tells those two apart.
--
-- ⭐⭐ DISJOINTNESS IS AN INVERTED CLAUSE, NOT A BAND SPLIT.  Both sibling arms
-- require the 1200 tower ring to be EMPTY; this one requires it to be OCCUPIED.
-- `overlap_tower_buy` and `overlap_tower_hurt` must therefore both be 0 across the
-- whole HP band, and the test asserts it -- no arm can ever be credited with
-- another arm's frames.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  The call site is an OR of three
-- predicates, so arming can only add TRUEs.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE; it must be 0.
--
-- ⚠️ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.  It measures a
-- PURCHASE PREDICATE turning true, not a trip home being cancelled and not a salve
-- being bought: the nine engine clauses guarding the actual
-- ActionImmediate_PurchaseItem (stock count, gold, stash, courier distance, empty
-- slot) are not readable from a fixture, and gold is not networked into a .dem at
-- all (GH #495).  `WIRE_*` asserts the wiring exists in item_purchase_generic.lua;
-- nothing here asserts the purchase happens.  Second bound, and it is specific to
-- THIS lever: 43 of the corpus fixtures carry no buildings at all (GH #100), so on
-- those frames the tower clause cannot be verified in either direction --
-- `fixtures_with_buildings` and `frames_with_buildings` are printed so the domain
-- is never mistaken for the corpus.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac>
--       one live frame where the call-site predicate flips false -> true under
--       'buytower' armed ALONE
--   B <fixture> <hero> <hp_frac> <why>
--       one live frame inside the band, carrying nothing drinkable, that this
--       lever REFUSES -- `why` is the clause that refused it (ring / attr /
--       no_tower).  The refusals are listed, not just counted, so "the lever is
--       narrow" is a readable set rather than a difference of two totals.
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
-- long comment naming J.IsSoakCandidate, the sibling ids, every constant and the
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
local tow = strip_comments(block(src, 'function J.ShouldFieldBuyRegenTower( bot )'))
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
G.SIT = sit and 1 or 0
G.BUY = buy and 1 or 0
G.HURT = hurt and 1 or 0
G.TOW = tow and 1 or 0
G.STAY = stay and 1 or 0
-- Did the stripping actually HAPPEN?  Asserted as its own fact rather than left to
-- be implied by some count coming out at the expected number.  It was implied once
-- ('staybag' round, M5): an exact id total was the only thing catching the "stop
-- stripping" mutant, and relaxing that total for an unrelated and correct reason
-- took the mutant's only detector with it.
G.SIT_STRIPPED = (sit and not sit:find('--', 1, true)) and 1 or 0
G.TOW_STRIPPED = (tow and not tow:find('--', 1, true)) and 1 or 0
G.STAY_STRIPPED = (stay and not stay:find('--', 1, true)) and 1 or 0

-- The gate, and the 'pullcad' invariant.  The trap is TWO IDS IN ONE CONDITION;
-- the per-condition maximum is the invariant, the per-function total is not.
G.TOW_SOAKID = (tow and tow:find("J.IsSoakCandidate( 'buytower' )", 1, true))
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
G.TOW_NIDS = count_ids(tow)
G.TOW_IDS_MAX_PER_COND = max_ids_per_cond(tow)
G.TOW_TURBO = (tow and tow:find('J.IsModeTurbo()', 1, true)) and 1 or 0
-- The shared predicate must stay untouched by this lever: its only id is the
-- pre-existing 'fieldcreep'.  A gate here would move 'stayfield', 'stayfield2' and
-- 'fieldbuy' with one arm -- the 'lanefix' bundle shape this design avoids.
G.SIT_NIDS = count_ids(sit)
G.SIT_HAS_BUYTOWER = (sit and sit:find('buytower', 1, true)) and 1 or 0

-- The band constants, parsed out of the two functions that already own them, so
-- "these are not new tuned numbers" is checked rather than asserted in prose.
G.STAY_HP_HI = stay and tonumber(stay:match('nHP > ([%d%.]+)')) or -1
G.SIT_HP_LO = sit and tonumber(sit:match('nHP < ([%d%.]+)')) or -1
G.SIT_HP_HI = sit and tonumber(sit:match('nHP > ([%d%.]+)')) or -1
G.TOW_HP_LO = tow and tonumber(tow:match('nHP < ([%d%.]+)')) or -1
G.TOW_HP_HI = tow and tonumber(tow:match('nHP > ([%d%.]+)')) or -1

-- ⭐ THE DRIFT GUARD, and it is the price of duplicating clauses instead of
-- calling the sibling.  Each surroundings constant is parsed from BOTH bodies; the
-- test asserts the two copies are equal, so the day either moves this file goes
-- red instead of the lever quietly measuring a different situation than the one
-- its comment describes.
G.SIT_RING = sit and tonumber(sit:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.TOW_RING = tow and tonumber(tow:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.SIT_ATTR_RADIUS =
    (sit and sit:find('GetNearbyHeroes( bot, 3000, true', 1, true)) and 3000 or -1
G.TOW_ATTR_RADIUS =
    (tow and tow:find('GetNearbyHeroes( bot, 3000, true', 1, true)) and 3000 or -1
G.SIT_TOWER = sit and tonumber(sit:match('GetNearbyTowers%( (%d+), true')) or -1
G.TOW_TOWER = tow and tonumber(tow:match('GetNearbyTowers%( (%d+), true')) or -1
G.SIT_ATTR_WINDOW =
    sit and tonumber(sit:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.TOW_ATTR_WINDOW =
    tow and tonumber(tow:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1

-- ⭐⭐ THE INVERSION, READ OFF THE SOURCE RATHER THAN TRUSTED.  The whole
-- disjointness argument rests on this lever testing `== 0 then return false`
-- against the siblings' `> 0 then return false`, and a mutant that flips the
-- comparison would leave every counter below looking plausible while the three
-- arms started overlapping.  Both directions are parsed.
G.TOW_TOWER_INVERTED =
    (tow and tow:find('GetNearbyTowers( 1200, true ) == 0', 1, true)) and 1 or 0
G.SIT_TOWER_PLAIN =
    (sit and sit:find('GetNearbyTowers( 1200, true ) > 0', 1, true)) and 1 or 0
G.HURT_TOWER_PLAIN =
    (hurt and hurt:find('GetNearbyTowers( 1200, true ) > 0', 1, true)) and 1 or 0

-- The shipped predicate is UNTOUCHED by this lever, and that is the claim the
-- seven-file re-baseline (the 'buyband' round) was reverted to keep true.  The
-- DEFINITION is subtracted rather than left in the total: `function
-- J.IsFieldRegenSituation( bot )` matches the call pattern itself.
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
G.TOW_CALLS_SIT = (tow and tow:find('IsFieldRegenSituation', 1, true)) and 1 or 0
-- The 'fieldcreep' veto is the one clause NOT copied (honest bound (4)): naming
-- another candidate's id here would freeze this clause FALSE the day that id is
-- promoted.  Asserted from both sides -- still in the sibling, still absent here.
G.SIT_HAS_FIELDCREEP =
    (sit and sit:find("J.IsSoakCandidate( 'fieldcreep' )", 1, true)) and 1 or 0
G.TOW_HAS_FIELDCREEP = (tow and tow:find('fieldcreep', 1, true)) and 1 or 0

-- The wiring.  The behaviour is a PURCHASE, and a fixture cannot reach the engine
-- clauses that guard it, so the one thing that can be checked here is that the
-- predicate is actually consulted at the purchase site -- and that it is consulted
-- as a THIRD OR ARM alongside both siblings, not in place of either.
local buysrc = strip_comments(read_file(BUY))
G.WIRE_TOW = buysrc:find('J.ShouldFieldBuyRegenTower(bot)', 1, true) and 1 or 0
G.WIRE_HURT = buysrc:find('J.ShouldFieldBuyRegenHurt(bot)', 1, true) and 1 or 0
G.WIRE_BUY = buysrc:find('J.ShouldFieldBuyRegen(bot)', 1, true) and 1 or 0
-- The three arms in ONE condition, matched across the line break the third arm
-- introduced.  A pattern rather than a literal because the wrapping is
-- whitespace, and whitespace is not what this assertion is about.
G.WIRE_OR3 = buysrc:find(
    'if %( J%.ShouldFieldBuyRegen%(bot%) or J%.ShouldFieldBuyRegenHurt%(bot%)%s*'
    .. 'or J%.ShouldFieldBuyRegenTower%(bot%) %)') and 1 or 0
-- Exactly one call site for the new arm: a second one would ship the behaviour
-- through a path this file never drives.
local nTowCalls = 0
for _ in buysrc:gmatch('J%.ShouldFieldBuyRegenTower%(') do
    nTowCalls = nTowCalls + 1
end
G.WIRE_TOW_CALLS = nTowCalls
local nTowCallsTree = 0
for _ in src_stripped:gmatch('J%.ShouldFieldBuyRegenTower%(') do
    nTowCallsTree = nTowCallsTree + 1
end
G.TOW_DEFS_IN_JMZ = nTowCallsTree
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
for _, k in ipairs({ 'fixtures', 'fixtures_with_buildings', 'live',
    'frames_with_buildings', 'turbo', 'raises', 'band_all', 'band_nosrc',
    'nosrc_ring_busy', 'nosrc_attr', 'nosrc_tower', 'nosrc_tower_only',
    'nosrc_clean', 'tower_domain', 'flips_buytower', 'flip_true_to_false',
    'overlap_tower_buy', 'overlap_tower_hurt', 'overlap_probe_runs', 'arm_leak',
    'tower_with_creep_damage', 'tower_with_bag_salve', 'tower_below_sit_ceiling',
    'tower_above_sit_ceiling' }) do
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
        local bBuildings = type(fx.buildings) == 'table' and #fx.buildings > 0
        if bBuildings then bump('fixtures_with_buildings') end
        for _, u in ipairs(fx.units) do
            if u.alive then
                local ok, J, bot = pcall(rf.load, path, u.name)
                if ok and bot ~= nil then
                    bump('live')
                    if bBuildings then bump('frames_with_buildings') end
                    local armed = false
                    J.IsSoakCandidate = function(sId)
                        return armed and sId == 'buytower'
                    end

                    local nHP = J.GetHP(bot)
                    local bTurbo = J.IsModeTurbo() and true or false
                    if bTurbo then bump('turbo') end

                    -- The call-site predicate TRIO, driven under two armings.
                    local function pred()
                        return J.ShouldFieldBuyRegen(bot)
                            or J.ShouldFieldBuyRegenHurt(bot)
                            or J.ShouldFieldBuyRegenTower(bot)
                    end
                    local ok1, shipped = pcall(pred)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them all
                    -- would let any other live id move this guard's answer while
                    -- the flip is still attributed to this lever (the M8 survivor
                    -- of the 'stayattr' round).  Asserted 0 downstream; the
                    -- siblings that would silently widen the same path are named.
                    if J.IsSoakCandidate('fieldbuy')
                        or J.IsSoakCandidate('buyband')
                        or J.IsSoakCandidate('fieldsip')
                        or J.IsSoakCandidate('fieldcreep')
                        or J.IsSoakCandidate('bagsalve') then
                        bump('arm_leak')
                    end
                    local ok2, arm = pcall(pred)
                    armed = false

                    if not (ok1 and ok2) then
                        bump('raises')
                    else
                        if arm and not shipped then bump('flips_buytower') end
                        if shipped and not arm then
                            -- Must never happen: the call site ORs a new arm in,
                            -- which can only add TRUEs.  Asserted 0 downstream.
                            bump('flip_true_to_false')
                        end
                        -- Disjointness, measured rather than argued.  Two arms
                        -- answering TRUE on one frame would mean one id can be
                        -- credited with the other's behaviour.
                        do
                            J.IsSoakCandidate = function(sId)
                                return sId == 'buytower'
                            end
                            local okt, towonly = pcall(J.ShouldFieldBuyRegenTower, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'fieldbuy'
                            end
                            local okb, buyarm = pcall(J.ShouldFieldBuyRegen, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'buyband'
                            end
                            local okh, hurtarm = pcall(J.ShouldFieldBuyRegenHurt, bot)
                            J.IsSoakCandidate = function(sId)
                                return armed and sId == 'buytower'
                            end
                            -- ⭐ The probe must PROVE it ran.  Both overlap
                            -- columns are claims whose whole content is a zero,
                            -- and a probe that stops driving prints the same zero
                            -- as a probe that drove 1012 frames and found nothing
                            -- (the GH #171 shape).  This counter is asserted equal
                            -- to the live frame count downstream, so "measured and
                            -- empty" and "not measured" stop being the same
                            -- reading.
                            if okt and okb and okh then bump('overlap_probe_runs') end
                            if okt and okb and towonly and buyarm then
                                bump('overlap_tower_buy')
                            end
                            if okt and okh and towonly and hurtarm then
                                bump('overlap_tower_hurt')
                            end
                        end
                    end

                    -- Independent prefix walk: this lever's OWN domain, in its own
                    -- clause order, with nothing armed.  Cross-checked against the
                    -- driven `flips_buytower` above -- the two must be equal.
                    local bRingBusy = #J.GetNearbyHeroes(bot, G.SIT_RING, true,
                        BOT_MODE_NONE) > 0
                    local bAttr = false
                    if bot:WasRecentlyDamagedByAnyHero(G.SIT_ATTR_WINDOW) then
                        for _, hEnemy in pairs(J.GetNearbyHeroes(bot, 3000, true,
                            BOT_MODE_NONE)) do
                            if J.IsValidHero(hEnemy)
                                and bot:WasRecentlyDamagedByHero(hEnemy,
                                    G.SIT_ATTR_WINDOW)
                            then
                                bAttr = true
                            end
                        end
                    end
                    local bTower = #bot:GetNearbyTowers(G.SIT_TOWER, true) > 0
                    local bMain = main_src(bot)

                    if bTurbo and nHP >= G.TOW_HP_LO and nHP <= G.TOW_HP_HI then
                        bump('band_all')
                        if not bMain then
                            bump('band_nosrc')
                            -- The census of what holds these frames out of the
                            -- family, so the lever's domain is a SLICE of a
                            -- printed partition rather than a lone number.
                            if bRingBusy then bump('nosrc_ring_busy') end
                            if bAttr then bump('nosrc_attr') end
                            if bTower then bump('nosrc_tower') end
                            if bTower and not bRingBusy and not bAttr then
                                bump('nosrc_tower_only')
                            end
                            if not bTower and not bRingBusy and not bAttr then
                                bump('nosrc_clean')
                            end
                            if bRingBusy or bAttr then
                                out:write(string.format('B %s %s %.4f %s\n',
                                    path:match('([^/]+)%.lua$'), u.name, nHP,
                                    bRingBusy and 'ring' or 'attr'))
                            elseif not bTower then
                                out:write(string.format('B %s %s %.4f no_tower\n',
                                    path:match('([^/]+)%.lua$'), u.name, nHP))
                            end
                        end
                    end

                    if bTurbo
                        and nHP >= G.TOW_HP_LO and nHP <= G.TOW_HP_HI
                        and not bRingBusy and not bAttr and bTower
                        and not bMain
                    then
                        bump('tower_domain')
                        -- Where this lever's domain sits relative to the sibling
                        -- ceiling, counted rather than described: 'fieldbuy' owns
                        -- <= 0.55 and 'buyband' the band above it, and this lever
                        -- crosses both -- which is only sound because the tower
                        -- clause is inverted, and these two columns are what make
                        -- that visible instead of assumed.
                        if nHP <= G.SIT_HP_HI then
                            bump('tower_below_sit_ceiling')
                        else
                            bump('tower_above_sit_ceiling')
                        end
                        -- The GH #123 asymmetry, same as it appears on both
                        -- siblings: a backpacked salve is invisible to
                        -- J.HasFieldRegenSource (it stops at slot 5) and is
                        -- caught at the call site by `bot:FindItemSlot` instead.
                        if bag_salve(bot) then bump('tower_with_bag_salve') end
                        -- Honest bound (4) as a column rather than a promise: the
                        -- one clause of J.IsFieldRegenSituation this function does
                        -- not copy is the gated 'fieldcreep' veto, so while that
                        -- id is armed the call-site arms disagree about a bot
                        -- being chewed by a camp.  This counts how wide that
                        -- disagreement actually is on this corpus.
                        if bot:WasRecentlyDamagedByCreep(G.SIT_ATTR_WINDOW) then
                            bump('tower_with_creep_damage')
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
