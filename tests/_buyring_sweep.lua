-- Heavy corpus sweep for tests/test_buyring_purchase_domain.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame must
-- not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  One CONSTANT is answered twice by the same family, over the
-- same health band, for the same question ("is an enemy near enough that this hurt
-- bot is not safe"):
--   * J.ShouldStayAndRegen -- PROMOTED, live in every turbo game -- says 1200;
--   * J.IsFieldRegenSituation and both buy arms say 1600, and the sibling's own
--     comment gives the reason: "the ring THE GUARDED BRANCH ITSELF MEASURES".
-- That reason is about the retreat bid 'stayfield'/'stayfield2' cancel.  The buy
-- arms cancel nothing -- they add an OR arm to a purchase -- so they inherited a
-- constant justified by a call site they do not have.  'buyring' is the standalone
-- lever for exactly the frames in the 1200-1600 gap.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR IS `flips_buyring`, AND WHY IT IS NONZERO.
-- The lever must be visible to a SINGLE-ARM isolation wave.  Putting the smaller
-- ring behind J.ShouldFieldBuyRegen's own 'fieldbuy' gate, or behind
-- J.ShouldFieldBuyRegenHurt's 'buyband' one, would make the new id unreachable
-- unless the sibling were armed too: two ids on one PATH, every site reading clean,
-- and any single-arm wave reading a CORRECT zero (the second form of the 'pullcad'
-- trap, GH #542).  `flips_buyring` is driven with nothing else armed.  A zero there
-- means the design failed, not that the corpus is thin -- `ring_domain`, the
-- independent prefix walk, is what tells those two apart.
--
-- ⭐⭐ DISJOINTNESS IS AN INVERTED CLAUSE, NOT A BAND SPLIT.  All three sibling
-- arms require the 1600 ring to be EMPTY; this one requires it to be OCCUPIED.
-- `overlap_ring_buy`, `overlap_ring_hurt` and `overlap_ring_tower` must therefore
-- all be 0 across the whole HP band, and the test asserts it -- no arm can ever be
-- credited with another arm's frames.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  The call site is an OR of four
-- predicates, so arming can only add TRUEs.  `flip_true_to_false` counts frames
-- where arming turns a TRUE into a FALSE; it must be 0.
--
-- ⚠️ WHAT THIS FILE CANNOT MEASURE, STATED RATHER THAN IMPLIED.  It measures a
-- PURCHASE PREDICATE turning true, not a trip home being cancelled and not a salve
-- being bought: the nine engine clauses guarding the actual
-- ActionImmediate_PurchaseItem (stock count, gold, stash, courier distance, empty
-- slot) are not readable from a fixture, and gold is not networked into a .dem at
-- all (GH #495).  `WIRE_*` asserts the wiring exists in item_purchase_generic.lua;
-- nothing here asserts the purchase happens.
--
-- Manifest grammar (one record per line, space-separated):
--   G <name> <value>    a constant / structural fact parsed out of the tree
--   C <key> <n>         a counter bucket
--   F <fixture> <hero> <hp_frac>
--       one live frame where the call-site predicate flips false -> true under
--       'buyring' armed ALONE
--   B <fixture> <hero> <hp_frac> <why>
--       one live frame inside the band, carrying nothing drinkable, that this
--       lever REFUSES -- `why` is the clause that refused it (chase / empty_ring /
--       attr / tower).  The refusals are listed, not just counted, so "the lever
--       is narrow" is a readable set rather than a difference of two totals.
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
local ring = strip_comments(block(src, 'function J.ShouldFieldBuyRegenRing( bot )'))
local stay = strip_comments(block(src, 'function J.ShouldStayAndRegen( bot )'))
G.SIT = sit and 1 or 0
G.BUY = buy and 1 or 0
G.HURT = hurt and 1 or 0
G.TOW = tow and 1 or 0
G.RING = ring and 1 or 0
G.STAY = stay and 1 or 0
-- Did the stripping actually HAPPEN?  Asserted as its own fact rather than left to
-- be implied by some count coming out at the expected number ('staybag' round, M5).
G.SIT_STRIPPED = (sit and not sit:find('--', 1, true)) and 1 or 0
G.RING_STRIPPED = (ring and not ring:find('--', 1, true)) and 1 or 0
G.STAY_STRIPPED = (stay and not stay:find('--', 1, true)) and 1 or 0

-- The gate, and the 'pullcad' invariant.  The trap is TWO IDS IN ONE CONDITION;
-- the per-condition maximum is the invariant, the per-function total is not.
G.RING_SOAKID = (ring and ring:find("J.IsSoakCandidate( 'buyring' )", 1, true))
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
G.RING_NIDS = count_ids(ring)
G.RING_IDS_MAX_PER_COND = max_ids_per_cond(ring)
G.RING_TURBO = (ring and ring:find('J.IsModeTurbo()', 1, true)) and 1 or 0
-- The shared predicate must stay untouched by this lever: its only id is the
-- pre-existing 'fieldcreep'.  A gate there would move 'stayfield', 'stayfield2'
-- and 'fieldbuy' with one arm -- the 'lanefix' bundle shape this design avoids.
G.SIT_NIDS = count_ids(sit)
G.SIT_HAS_BUYRING = (sit and sit:find('buyring', 1, true)) and 1 or 0

-- The band constants, parsed out of the two functions that already own them, so
-- "these are not new tuned numbers" is checked rather than asserted in prose.
G.STAY_HP_HI = stay and tonumber(stay:match('nHP > ([%d%.]+)')) or -1
G.SIT_HP_LO = sit and tonumber(sit:match('nHP < ([%d%.]+)')) or -1
G.SIT_HP_HI = sit and tonumber(sit:match('nHP > ([%d%.]+)')) or -1
G.RING_HP_LO = ring and tonumber(ring:match('nHP < ([%d%.]+)')) or -1
G.RING_HP_HI = ring and tonumber(ring:match('nHP > ([%d%.]+)')) or -1

-- ⭐ THE TWO RINGS, AND THEY ARE THE WHOLE LEVER.  Each is parsed from the body
-- that owns it AND from this lever's copy, so "1200 is the promoted number, 1600 is
-- the inherited one" is checked rather than described.  The day either owner moves,
-- this file goes red instead of the lever quietly measuring a different gap.
G.STAY_RING = stay and tonumber(stay:match('GetNearbyHeroes%( bot, (%d+), true'))
    or -1
G.SIT_RING = sit and tonumber(sit:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.RING_CHASE = ring
    and tonumber(ring:match('nChasers = #J.GetNearbyHeroes%( bot, (%d+), true')) or -1
G.RING_RING = ring
    and tonumber(ring:match('nRing = #J.GetNearbyHeroes%( bot, (%d+), true')) or -1
G.RING_ATTR_RADIUS = ring
    and tonumber(ring:match('hDamagers = J.GetNearbyHeroes%( bot, (%d+), true')) or -1
G.RING_TOWER = ring
    and tonumber(ring:match('nTowers = #bot:GetNearbyTowers%( (%d+), true')) or -1
G.SIT_TOWER = sit and tonumber(sit:match('GetNearbyTowers%( (%d+), true')) or -1
G.SIT_ATTR_RADIUS =
    (sit and sit:find('GetNearbyHeroes( bot, 3000, true', 1, true)) and 3000 or -1
G.SIT_ATTR_WINDOW =
    sit and tonumber(sit:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.RING_ATTR_WINDOW =
    ring and tonumber(ring:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1

-- ⭐⭐ THE INVERSION, READ OFF THE SOURCE RATHER THAN TRUSTED.  The whole
-- disjointness argument rests on this lever testing `nRing == 0 then return false`
-- against the siblings' `> 0 then return false`, and a mutant that flips the
-- comparison would leave every counter below looking plausible while the four arms
-- started overlapping.  Both directions are parsed, and so is the clause that is
-- NOT inverted -- the promoted 1200 ring keeps its full veto.
G.RING_INVERTED = (ring and ring:find('nRing == 0 then return false', 1, true))
    and 1 or 0
G.RING_CHASE_PLAIN = (ring and ring:find('nChasers > 0 then return false', 1, true))
    and 1 or 0
G.SIT_RING_PLAIN = (sit
    and sit:find('GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0', 1, true))
    and 1 or 0
G.HURT_RING_PLAIN = (hurt
    and hurt:find('GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0', 1, true))
    and 1 or 0
G.TOW_RING_PLAIN = (tow
    and tow:find('GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0', 1, true))
    and 1 or 0
-- The tower clause is the one this lever keeps in its SHIPPED direction, because
-- moving two clauses at once is two levers.  'buytower' is the arm that inverts it.
G.RING_TOWER_PLAIN = (ring and ring:find('nTowers > 0 then return false', 1, true))
    and 1 or 0

-- The shipped predicate is UNTOUCHED by this lever.  The DEFINITION is subtracted
-- rather than left in the total: `function J.IsFieldRegenSituation( bot )` matches
-- the call pattern itself.
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
G.RING_CALLS_SIT = (ring and ring:find('IsFieldRegenSituation', 1, true)) and 1 or 0
-- Nor does it route the attribution scan through J.HasNearbyHeroDamager, whose
-- one-caller invariant tests/test_stayattr_global_ult.lua asserts BY COUNT -- a
-- second caller there would turn this lever into a red in another lever's file.
G.RING_CALLS_DAMAGER =
    (ring and ring:find('HasNearbyHeroDamager', 1, true)) and 1 or 0
-- The 'fieldcreep' veto is the one clause NOT copied: naming another candidate's id
-- here would freeze this clause FALSE the day that id is promoted.  Asserted from
-- both sides -- still in the sibling, still absent here.
G.SIT_HAS_FIELDCREEP =
    (sit and sit:find("J.IsSoakCandidate( 'fieldcreep' )", 1, true)) and 1 or 0
G.RING_HAS_FIELDCREEP = (ring and ring:find('fieldcreep', 1, true)) and 1 or 0

-- The wiring.  The behaviour is a PURCHASE, and a fixture cannot reach the engine
-- clauses that guard it, so the one thing that can be checked here is that the
-- predicate is actually consulted at the purchase site -- and that it is consulted
-- as a FOURTH OR arm alongside all three siblings, not in place of any.
local buysrc = strip_comments(read_file(BUY))
G.WIRE_RING = buysrc:find('J.ShouldFieldBuyRegenRing(bot)', 1, true) and 1 or 0
G.WIRE_TOW = buysrc:find('J.ShouldFieldBuyRegenTower(bot)', 1, true) and 1 or 0
G.WIRE_HURT = buysrc:find('J.ShouldFieldBuyRegenHurt(bot)', 1, true) and 1 or 0
G.WIRE_BUY = buysrc:find('J.ShouldFieldBuyRegen(bot)', 1, true) and 1 or 0
-- The four arms in ONE condition, matched across the line breaks the wrapping
-- introduces.  A pattern rather than a literal because the wrapping is whitespace,
-- and whitespace is not what this assertion is about -- and written so a further
-- arm of the same OR still passes while a replacement or an `and` still fails.
G.WIRE_OR4 = buysrc:find(
    'if %( J%.ShouldFieldBuyRegen%(bot%) or J%.ShouldFieldBuyRegenHurt%(bot%)%s*'
    .. 'or J%.ShouldFieldBuyRegenTower%(bot%) or J%.ShouldFieldBuyRegenRing%(bot%)')
    and 1 or 0
-- Exactly one call site for the new arm: a second one would ship the behaviour
-- through a path this file never drives.
local nRingCalls = 0
for _ in buysrc:gmatch('J%.ShouldFieldBuyRegenRing%(') do
    nRingCalls = nRingCalls + 1
end
G.WIRE_RING_CALLS = nRingCalls
local nRingInJmz = 0
for _ in src_stripped:gmatch('J%.ShouldFieldBuyRegenRing%(') do
    nRingInJmz = nRingInJmz + 1
end
G.RING_DEFS_IN_JMZ = nRingInJmz
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
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'raises', 'band_all',
    'band_nosrc', 'nosrc_ring_busy', 'nosrc_chase_busy', 'nosrc_annulus',
    'nosrc_annulus_attr', 'nosrc_annulus_tower', 'nosrc_attr', 'nosrc_tower',
    'nosrc_clean', 'ring_domain', 'flips_buyring', 'flip_true_to_false',
    'overlap_ring_buy', 'overlap_ring_hurt', 'overlap_ring_tower',
    'overlap_probe_runs', 'arm_leak', 'ring_with_creep_damage',
    'ring_with_bag_salve', 'ring_below_sit_ceiling', 'ring_above_sit_ceiling' }) do
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
                        return armed and sId == 'buyring'
                    end

                    local nHP = J.GetHP(bot)
                    local bTurbo = J.IsModeTurbo() and true or false
                    if bTurbo then bump('turbo') end

                    -- The call-site predicate QUARTET, driven under two armings.
                    local function pred()
                        return J.ShouldFieldBuyRegen(bot)
                            or J.ShouldFieldBuyRegenHurt(bot)
                            or J.ShouldFieldBuyRegenTower(bot)
                            or J.ShouldFieldBuyRegenRing(bot)
                    end
                    local ok1, shipped = pcall(pred)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them all
                    -- would let any other live id move this guard's answer while
                    -- the flip is still attributed to this lever (the M8 survivor
                    -- of the 'stayattr' round).
                    if J.IsSoakCandidate('fieldbuy')
                        or J.IsSoakCandidate('buyband')
                        or J.IsSoakCandidate('buytower')
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
                        if arm and not shipped then bump('flips_buyring') end
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
                                return sId == 'buyring'
                            end
                            local okr, ringonly = pcall(J.ShouldFieldBuyRegenRing, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'fieldbuy'
                            end
                            local okb, buyarm = pcall(J.ShouldFieldBuyRegen, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'buyband'
                            end
                            local okh, hurtarm = pcall(J.ShouldFieldBuyRegenHurt, bot)
                            J.IsSoakCandidate = function(sId)
                                return sId == 'buytower'
                            end
                            local okt, towarm = pcall(J.ShouldFieldBuyRegenTower, bot)
                            J.IsSoakCandidate = function(sId)
                                return armed and sId == 'buyring'
                            end
                            -- ⭐ The probe must PROVE it ran.  All three overlap
                            -- columns are claims whose whole content is a zero, and
                            -- a probe that stops driving prints the same zero as a
                            -- probe that drove 1012 frames and found nothing (the
                            -- GH #171 shape).
                            if okr and okb and okh and okt then
                                bump('overlap_probe_runs')
                            end
                            if okr and okb and ringonly and buyarm then
                                bump('overlap_ring_buy')
                            end
                            if okr and okh and ringonly and hurtarm then
                                bump('overlap_ring_hurt')
                            end
                            if okr and okt and ringonly and towarm then
                                bump('overlap_ring_tower')
                            end
                        end
                    end

                    -- Independent prefix walk: this lever's OWN domain, in its own
                    -- clause order, with nothing armed.  Cross-checked against the
                    -- driven `flips_buyring` above -- the two must be equal.
                    local bChase = #J.GetNearbyHeroes(bot, G.STAY_RING, true,
                        BOT_MODE_NONE) > 0
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

                    if bTurbo and nHP >= G.RING_HP_LO and nHP <= G.RING_HP_HI then
                        bump('band_all')
                        if not bMain then
                            bump('band_nosrc')
                            -- The census of what holds these frames out of the
                            -- family, so the lever's domain is a SLICE of a
                            -- printed partition rather than a lone number.
                            if bRingBusy then bump('nosrc_ring_busy') end
                            if bChase then bump('nosrc_chase_busy') end
                            if bAttr then bump('nosrc_attr') end
                            if bTower then bump('nosrc_tower') end
                            if not bTower and not bRingBusy and not bAttr then
                                bump('nosrc_clean')
                            end
                            -- ⭐ The gap this lever is about: inside the inherited
                            -- 1600 ring, outside the PROMOTED 1200 one.
                            if bRingBusy and not bChase then
                                bump('nosrc_annulus')
                                if bAttr then bump('nosrc_annulus_attr') end
                                if bTower then bump('nosrc_annulus_tower') end
                            end
                            local sWhy = nil
                            if bChase then sWhy = 'chase'
                            elseif not bRingBusy then sWhy = 'empty_ring'
                            elseif bAttr then sWhy = 'attr'
                            elseif bTower then sWhy = 'tower' end
                            if sWhy ~= nil then
                                out:write(string.format('B %s %s %.4f %s\n',
                                    path:match('([^/]+)%.lua$'), u.name, nHP, sWhy))
                            end
                        end
                    end

                    if bTurbo
                        and nHP >= G.RING_HP_LO and nHP <= G.RING_HP_HI
                        and not bChase and bRingBusy and not bAttr and not bTower
                        and not bMain
                    then
                        bump('ring_domain')
                        -- Where this lever's domain sits relative to the sibling
                        -- ceiling, counted rather than described: 'fieldbuy' owns
                        -- <= 0.55 and 'buyband' the band above it, and this lever
                        -- crosses both -- which is only sound because the ring
                        -- clause is inverted.
                        if nHP <= G.SIT_HP_HI then
                            bump('ring_below_sit_ceiling')
                        else
                            bump('ring_above_sit_ceiling')
                        end
                        -- The GH #123 asymmetry, same as on all three siblings: a
                        -- backpacked salve is invisible to J.HasFieldRegenSource
                        -- (it stops at slot 5) and is caught at the call site by
                        -- `bot:FindItemSlot` instead.
                        if bag_salve(bot) then bump('ring_with_bag_salve') end
                        -- The honest bound as a column rather than a promise: the
                        -- one clause of J.IsFieldRegenSituation this function does
                        -- not copy is the gated 'fieldcreep' veto, so while that id
                        -- is armed the call-site arms disagree about a bot being
                        -- chewed by a camp.  This counts how wide that
                        -- disagreement actually is on this corpus.
                        if bot:WasRecentlyDamagedByCreep(G.SIT_ATTR_WINDOW) then
                            bump('ring_with_creep_damage')
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
