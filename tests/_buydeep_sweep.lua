-- Heavy corpus sweep for tests/test_buydeep_purchase_floor.lua, run as a
-- SUBPROCESS: a full-corpus drive that rebuilds jmz_func once per hero-frame must
-- not run on run_tests.lua's long-lived heap.  The leading underscore keeps
-- run_tests.lua from globbing it (it globs `^test_.*%.lua$`).
--
-- WHAT IS MEASURED.  J.IsFieldRegenSituation has four clauses that decide whether
-- the SUPPLY side of owner priority P2 is offered at all -- a floor, a ceiling, a
-- ring and a tower -- and three of the four have now each been answered by their
-- own standalone purchase arm ('buyband' the ceiling, 'buyring' the ring,
-- 'buytower' the tower).  This is the fourth and last: the FLOOR, `nHP < 0.18 ->
-- false`, whose own comment gives a HOLD-side reason -- "below the floor the
-- genuine escape retreat stands".  A purchase cancels no retreat, so that reason
-- does not transfer, and 'buydeep' is the arm for the frames below it.
--
-- ⭐ THE COLUMN THIS FILE EXISTS FOR IS `stop_source_*`, AND IT IS A CORRECTION.
-- tests/_tpdeep_sweep.lua left `stop_source 8` behind: eight frames inside the
-- '回复状态' branch trigger, inside the deep band, that the DECISION side refuses
-- because the bot has nothing to drink.  Eight empty-handed frames is what a
-- supply arm is for -- and taking that 8 as this lever's domain would have been
-- wrong, because **8 says "no supply", it does not say "safe"**.  This file
-- splits the 8 by the clauses this arm KEEPS: `stop_source_attr`,
-- `stop_source_ring`, `stop_source_domain`.  The last of those three, not the 8,
-- is the branch-trigger slice of the domain.
--
-- ⭐⭐ THE BOTTOM EDGE IS ABSENT ON PURPOSE, AND THE ABSENCE IS PINNED.  The
-- decision-side lever in this same band (J.ShouldDeepSipNotTpRecover, 'tpdeep')
-- carries a 0.10 bottom because a 115-135 field sip cannot lift a bot back over
-- the family's own 0.18 floor.  A salve is 400 -- 0.29-0.44 of max health across
-- the level-6+ turbo range that arithmetic is built on -- so the bottom is
-- arithmetically absent here.  `DEEP_NO_LOW_EDGE` asserts the body contains no
-- lower comparison at all, because an absence is exactly what a later round
-- "harmonises" in without noticing; `deep_below_tpdeep_floor` REGISTERS how much
-- domain a copied bottom would have discarded, and is a reading, never the pin.
--
-- ⭐⭐⭐ DISJOINTNESS IS AN INVERTED CLAUSE, NOT A BAND SPLIT.  All four sibling
-- arms require `nHP >= 0.18` -- 'fieldbuy' through J.IsFieldRegenSituation, the
-- other three in their own first band statement -- and this one requires
-- `nHP < 0.18`.  The four overlap columns must therefore all be 0, and the test
-- asserts it rather than arguing it.
--
-- ⛔ DIRECTION IS ASSERTED, NOT CLAIMED.  The call site is an OR of five
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
--       'buydeep' armed ALONE
--   B <fixture> <hero> <hp_frac> <why>
--       one live frame below the floor, carrying nothing drinkable, that this
--       lever REFUSES -- `why` is the clause that refused it (ring / attr /
--       tower).  Refusals are listed, not just counted, so "the lever is narrow"
--       is a readable set rather than a difference of two totals.
--   S <fixture> <hero> <hp_frac> <why>
--       one of the `stop_source` frames tests/_tpdeep_sweep.lua counted, with the
--       clause this arm answers it with (ring / attr / tower / domain).
--   DONE
-- Absence of the final DONE line is a failed subprocess.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local out = io.stdout
local JMZ = 'bots/FunLib/jmz_func.lua'
local BUY = 'bots/item_purchase_generic.lua'
local AIUG = 'bots/ability_item_usage_generic.lua'

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
-- assertions (the §EN mistake).
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
local deep = strip_comments(block(src, 'function J.ShouldFieldBuyRegenDeep( bot )'))
local tpdeep = strip_comments(block(src, 'function J.ShouldDeepSipNotTpRecover( bot )'))
G.SIT = sit and 1 or 0
G.DEEP = deep and 1 or 0
G.TPDEEP = tpdeep and 1 or 0
-- Did the stripping actually HAPPEN?  Asserted as its own fact rather than left
-- to be implied by some count coming out at the expected number.
G.SIT_STRIPPED = (sit and not sit:find('--', 1, true)) and 1 or 0
G.DEEP_STRIPPED = (deep and not deep:find('--', 1, true)) and 1 or 0

-- The gate, and the 'pullcad' invariant.  The trap is TWO IDS IN ONE CONDITION;
-- the per-condition maximum is the invariant, the per-function total is not.
G.DEEP_SOAKID = (deep and deep:find("J.IsSoakCandidate( 'buydeep' )", 1, true))
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
G.DEEP_NIDS = count_ids(deep)
G.DEEP_IDS_MAX_PER_COND = max_ids_per_cond(deep)
G.DEEP_TURBO = (deep and deep:find('J.IsModeTurbo()', 1, true)) and 1 or 0
-- Gate-first: nothing may be read before the id is asked.  Missing positions are
-- +inf so an ABSENT clause cannot flip this flag (each clause is pinned below).
local INF = math.huge
local at_gate = deep and deep:find("IsSoakCandidate( 'buydeep' )", 1, true)
local at_turbo = deep and deep:find('IsModeTurbo()', 1, true)
local at_hp = deep and deep:find('J.GetHP(', 1, true)
local at_ring = deep and deep:find('GetNearbyHeroes', 1, true)
G.DEEP_GATE_FIRST = (at_gate and at_turbo
    and at_gate < at_turbo
    and at_gate < (at_hp or INF)
    and at_gate < (at_ring or INF)) and 1 or 0
-- The shared predicate must stay untouched by this lever: its only id is the
-- pre-existing 'fieldcreep'.  A gate there would move 'stayfield', 'stayfield2'
-- and 'fieldbuy' with one arm -- the 'lanefix' bundle shape this design avoids.
G.SIT_NIDS = count_ids(sit)
G.SIT_HAS_BUYDEEP = (sit and sit:find('buydeep', 1, true)) and 1 or 0

-- ⭐ THE INVERSION, READ OFF THE SOURCE RATHER THAN TRUSTED.  The whole
-- disjointness argument rests on this lever testing `nHP >= 0.18 then return
-- false` against the siblings' `nHP < 0.18 then return false`, and a mutant that
-- flipped the comparison would leave every counter below looking plausible while
-- the five arms started overlapping.
-- Parsed off the INLINE form the lever is written in.  It is written inline
-- because the `local nHP` two-liner is byte-identical to
-- J.ShouldDeepSipNotTpRecover's band edge, which tools/agent/mutstand_tpdeep.sh
-- anchors on -- GH #550, and the reason is recorded in the lever's own block.
G.DEEP_FLOOR = deep
    and tonumber(deep:match('J%.GetHP%( bot %) >= ([%d%.]+) then return false')) or -1
-- ...and the inline form is asserted as its own fact, so a later round that
-- "tidies" it back into a local goes red HERE rather than inside a sibling's
-- mutation stand, where the failure would be attributed to that sibling.
G.DEEP_FLOOR_INLINE = (deep
    and deep:find('J.GetHP( bot ) >= 0.18 then return false', 1, true)) and 1 or 0
local nBandLines = 0
for _ in src:gmatch('\tif nHP >= 0%.18 then return false end') do
    nBandLines = nBandLines + 1
end
G.TPDEEP_BAND_LINE_COUNT = nBandLines
G.SIT_HP_LO = sit and tonumber(sit:match('nHP < ([%d%.]+)')) or -1
G.SIT_HP_HI = sit and tonumber(sit:match('nHP > ([%d%.]+)')) or -1
-- The three siblings' own floors, so "all four require >= 0.18" is arithmetic
-- between parsed constants rather than a sentence.
G.HURT_HP_LO = hurt and tonumber(hurt:match('nHP < ([%d%.]+)')) or -1
G.TOW_HP_LO = tow and tonumber(tow:match('nHP < ([%d%.]+)')) or -1
G.RING_HP_LO = ring and tonumber(ring:match('nHP < ([%d%.]+)')) or -1
-- ⛔ THE DELIBERATE ABSENCE.  There is no bottom edge, and the reason is the
-- arithmetic in the block above (a salve is 400, a field sip is 115-135).  An
-- absence is what a later round harmonises in without noticing, so it is asserted
-- as a fact: no lower comparison on nHP anywhere in this body.
-- Both spellings are counted -- the inline `J.GetHP( bot ) <` this lever uses and
-- the `local nHP` form a tidying round would introduce -- so the absence cannot be
-- restored through the door this file does not watch.
local nLowCmp = 0
if deep then
    for _ in deep:gmatch('nHP <') do nLowCmp = nLowCmp + 1 end
    for _ in deep:gmatch('GetHP%( bot %) <') do nLowCmp = nLowCmp + 1 end
end
G.DEEP_NO_LOW_EDGE = (nLowCmp == 0) and 1 or 0
-- ...and the sibling decision-side lever DOES carry one, so the absence above is
-- a difference between two levers rather than a habit of this family.
G.TPDEEP_LOW_EDGE = tpdeep and tonumber(tpdeep:match('nHP < ([%d%.]+)')) or -1

-- The three surroundings clauses, parsed from the body that owns them AND from
-- this lever's copy, so "these are not new tuned numbers" is checked rather than
-- described.  The day either copy moves, this file goes red instead of the lever
-- quietly measuring a different situation.
G.SIT_RING = sit and tonumber(sit:match('GetNearbyHeroes%( bot, (%d+), true')) or -1
G.DEEP_RING = deep and tonumber(deep:match('GetNearbyHeroes%( bot, (%d+), true'))
    or -1
G.SIT_TOWER = sit and tonumber(sit:match('GetNearbyTowers%( (%d+), true')) or -1
G.DEEP_TOWER = deep and tonumber(deep:match('GetNearbyTowers%( (%d+), true')) or -1
G.SIT_ATTR_WINDOW =
    sit and tonumber(sit:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.DEEP_ATTR_WINDOW =
    deep and tonumber(deep:match('WasRecentlyDamagedByAnyHero%( ([%d%.]+) %)')) or -1
G.SIT_ATTR_RADIUS =
    (sit and sit:find('GetNearbyHeroes( bot, 3000, true', 1, true)) and 3000 or -1
G.DEEP_ATTR_RADIUS =
    (deep and deep:find('GetNearbyHeroes( bot, 3000, true', 1, true)) and 3000 or -1
-- ...and all three are kept in their SHIPPED direction: the ONLY clause this
-- lever moves is the floor.  Read from both sides.
G.DEEP_RING_PLAIN = (deep
    and deep:find('GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0', 1, true))
    and 1 or 0
G.SIT_RING_PLAIN = (sit
    and sit:find('GetNearbyHeroes( bot, 1600, true, BOT_MODE_NONE ) > 0', 1, true))
    and 1 or 0
G.DEEP_TOWER_PLAIN = (deep
    and deep:find('GetNearbyTowers( 1200, true ) > 0', 1, true)) and 1 or 0
G.SIT_TOWER_PLAIN = (sit
    and sit:find('GetNearbyTowers( 1200, true ) > 0', 1, true)) and 1 or 0

-- The shipped predicate is UNTOUCHED by this lever: it repeats three clauses
-- instead of calling it.
G.DEEP_CALLS_SIT = (deep and deep:find('IsFieldRegenSituation', 1, true)) and 1 or 0
-- Nor does it route the attribution scan through J.HasNearbyHeroDamager, whose
-- one-caller invariant tests/test_stayattr_global_ult.lua asserts BY COUNT -- a
-- second caller there would turn this lever into a red in another lever's file.
G.DEEP_CALLS_DAMAGER =
    (deep and deep:find('HasNearbyHeroDamager', 1, true)) and 1 or 0
-- The 'fieldcreep' veto is the one clause NOT copied: naming another candidate's
-- id here would freeze this clause FALSE the day that id is promoted.  Asserted
-- from both sides -- still in the sibling, still absent here.
G.SIT_HAS_FIELDCREEP =
    (sit and sit:find("J.IsSoakCandidate( 'fieldcreep' )", 1, true)) and 1 or 0
G.DEEP_HAS_FIELDCREEP = (deep and deep:find('fieldcreep', 1, true)) and 1 or 0

-- The branch tests/_tpdeep_sweep.lua measured `stop_source` inside, so the
-- correction below is read against constants that came from the tree.
local function aiug_branch(s, sHead, sMotive)
    local a = s:find(sHead, 1, true)
    if a == nil then return nil end
    local b = s:find("sCastMotive = '" .. sMotive .. "'", a, true)
    if b == nil then return nil end
    return strip_comments(s:sub(a, b))
end
local b4 = aiug_branch(read_file(AIUG), 'if ( botHP + botMP < 0.3 or botHP < 0.2 )',
    '回复状态')
G.RECOVER_BRANCH = b4 and 1 or 0
G.RECOVER_HP_TRIGGER = tonumber(b4 and b4:match('botHP < ([%d%.]+)')) or -1
G.RECOVER_SUM_TRIGGER = tonumber(b4 and b4:match('botHP %+ botMP < ([%d%.]+)')) or -1

-- The wiring.  The behaviour is a PURCHASE, and a fixture cannot reach the engine
-- clauses that guard it, so the one thing that can be checked here is that the
-- predicate is actually consulted at the purchase site -- and that it is consulted
-- as a FIFTH OR arm alongside all four siblings, not in place of any.
local src_stripped = strip_comments(src)
local buysrc = strip_comments(read_file(BUY))
G.WIRE_DEEP = buysrc:find('J.ShouldFieldBuyRegenDeep(bot)', 1, true) and 1 or 0
G.WIRE_RING = buysrc:find('J.ShouldFieldBuyRegenRing(bot)', 1, true) and 1 or 0
G.WIRE_TOW = buysrc:find('J.ShouldFieldBuyRegenTower(bot)', 1, true) and 1 or 0
G.WIRE_HURT = buysrc:find('J.ShouldFieldBuyRegenHurt(bot)', 1, true) and 1 or 0
G.WIRE_BUY = buysrc:find('J.ShouldFieldBuyRegen(bot)', 1, true) and 1 or 0
-- The five arms in ONE condition, matched across the line breaks the wrapping
-- introduces.  A pattern rather than a literal because the wrapping is whitespace,
-- and whitespace is not what this assertion is about -- and written so a further
-- arm of the same OR still passes while a replacement or an `and` still fails.
G.WIRE_OR5 = buysrc:find(
    'if %( J%.ShouldFieldBuyRegen%(bot%) or J%.ShouldFieldBuyRegenHurt%(bot%)%s*'
    .. 'or J%.ShouldFieldBuyRegenTower%(bot%) or J%.ShouldFieldBuyRegenRing%(bot%)%s*'
    .. 'or J%.ShouldFieldBuyRegenDeep%(bot%)')
    and 1 or 0
-- Exactly one call site for the new arm: a second one would ship the behaviour
-- through a path this file never drives.
local nDeepCalls = 0
for _ in buysrc:gmatch('J%.ShouldFieldBuyRegenDeep%(') do
    nDeepCalls = nDeepCalls + 1
end
G.WIRE_DEEP_CALLS = nDeepCalls
local nDeepInJmz = 0
for _ in src_stripped:gmatch('J%.ShouldFieldBuyRegenDeep%(') do
    nDeepInJmz = nDeepInJmz + 1
end
G.DEEP_DEFS_IN_JMZ = nDeepInJmz
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
for _, k in ipairs({ 'fixtures', 'live', 'turbo', 'raises', 'below_floor',
    'below_floor_nosrc', 'nosrc_ring_busy', 'nosrc_attr', 'nosrc_tower',
    'deep_domain', 'flips_buydeep', 'flip_true_to_false',
    'overlap_deep_buy', 'overlap_deep_hurt', 'overlap_deep_tower',
    'overlap_deep_ring', 'overlap_probe_runs', 'arm_leak',
    'deep_with_creep_damage', 'deep_with_bag_salve', 'deep_with_any_tower',
    'deep_below_tpdeep_floor', 'trigger_deep_nosrc', 'stop_source_ring',
    'stop_source_attr', 'stop_source_tower', 'stop_source_domain',
    'nosrc_attr_only', 'stop_source_attr_any' }) do
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
                        return armed and sId == 'buydeep'
                    end

                    local nHP = J.GetHP(bot)
                    local bTurbo = J.IsModeTurbo() and true or false
                    if bTurbo then bump('turbo') end

                    -- The call-site predicate QUINTET, driven under two armings.
                    local function pred()
                        return J.ShouldFieldBuyRegen(bot)
                            or J.ShouldFieldBuyRegenHurt(bot)
                            or J.ShouldFieldBuyRegenTower(bot)
                            or J.ShouldFieldBuyRegenRing(bot)
                            or J.ShouldFieldBuyRegenDeep(bot)
                    end
                    local ok1, shipped = pcall(pred)
                    armed = true
                    -- The arming must be ONE id wide.  A stub that armed them all
                    -- would let any other live id move this guard's answer while
                    -- the flip is still attributed to this lever.
                    if J.IsSoakCandidate('fieldbuy')
                        or J.IsSoakCandidate('buyband')
                        or J.IsSoakCandidate('buytower')
                        or J.IsSoakCandidate('buyring')
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
                        if arm and not shipped then bump('flips_buydeep') end
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
                                return sId == 'buydeep'
                            end
                            local okd, deeponly = pcall(J.ShouldFieldBuyRegenDeep, bot)
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
                                return sId == 'buyring'
                            end
                            local okr, ringarm = pcall(J.ShouldFieldBuyRegenRing, bot)
                            J.IsSoakCandidate = function(sId)
                                return armed and sId == 'buydeep'
                            end
                            -- ⭐ The probe must PROVE it ran.  All four overlap
                            -- columns are claims whose whole content is a zero, and
                            -- a probe that stops driving prints the same zero as a
                            -- probe that drove the whole corpus and found nothing
                            -- (the GH #171 shape).
                            if okd and okb and okh and okt and okr then
                                bump('overlap_probe_runs')
                            end
                            if okd and okb and deeponly and buyarm then
                                bump('overlap_deep_buy')
                            end
                            if okd and okh and deeponly and hurtarm then
                                bump('overlap_deep_hurt')
                            end
                            if okd and okt and deeponly and towarm then
                                bump('overlap_deep_tower')
                            end
                            if okd and okr and deeponly and ringarm then
                                bump('overlap_deep_ring')
                            end
                        end
                    end

                    -- Independent prefix walk: this lever's OWN domain, in its own
                    -- clause order, with nothing armed.  Cross-checked against the
                    -- driven `flips_buydeep` above -- the two must be equal.
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
                    local bClean = not bRingBusy and not bAttr and not bTower

                    if bTurbo and nHP < G.DEEP_FLOOR then
                        bump('below_floor')
                        -- Anti-vacuum for the tower clause: 43 of the corpus
                        -- fixtures carry no buildings at all, so a zero in
                        -- `nosrc_tower` could equally mean "the mock answers {}".
                        -- This says whether the world has an enemy tower AT ALL.
                        if #bot:GetNearbyTowers(20000, true) > 0 then
                            bump('deep_with_any_tower')
                        end
                        if not bMain then
                            bump('below_floor_nosrc')
                            -- The census of what holds these frames out of the
                            -- family, so the lever's domain is a SLICE of a printed
                            -- partition rather than a lone number.
                            if bRingBusy then bump('nosrc_ring_busy') end
                            if bAttr then bump('nosrc_attr') end
                            if bTower then bump('nosrc_tower') end
                            -- ⭐ ORDER-FREE, and it is the reason the prefix walk
                            -- below can print `stop_source_attr 0` without that
                            -- zero meaning "attribution is silent here": a prefix
                            -- walk reports the FIRST clause that refuses, so an
                            -- attributed frame that is ALSO inside the ring is
                            -- filed under the ring.  This counts the frames
                            -- attribution refuses ALONE -- its own marginal price.
                            if bAttr and not bRingBusy then bump('nosrc_attr_only') end
                            local sWhy = nil
                            if bRingBusy then sWhy = 'ring'
                            elseif bAttr then sWhy = 'attr'
                            elseif bTower then sWhy = 'tower' end
                            if sWhy ~= nil then
                                out:write(string.format('B %s %s %.4f %s\n',
                                    path:match('([^/]+)%.lua$'), u.name, nHP, sWhy))
                            end
                        end
                    end

                    if bTurbo and nHP < G.DEEP_FLOOR and not bMain and bClean then
                        bump('deep_domain')
                        -- ⭐ THE READING, NEVER THE PIN.  How much of this arm's
                        -- domain a copied 'tpdeep' bottom would have discarded.
                        -- The absence of a bottom edge is pinned STRUCTURALLY
                        -- (DEEP_NO_LOW_EDGE); this number only says what it costs.
                        if nHP < G.TPDEEP_LOW_EDGE then
                            bump('deep_below_tpdeep_floor')
                        end
                        -- The GH #123 asymmetry, same as on all four siblings: a
                        -- backpacked salve is invisible to J.HasFieldRegenSource
                        -- (it stops at slot 5) and is caught at the call site by
                        -- `bot:FindItemSlot` instead.
                        if bag_salve(bot) then bump('deep_with_bag_salve') end
                        -- The honest bound as a column rather than a promise: the
                        -- one clause of J.IsFieldRegenSituation this function does
                        -- not copy is the gated 'fieldcreep' veto, so while that id
                        -- is armed the call-site arms disagree about a bot being
                        -- chewed by a camp.  This counts how wide that
                        -- disagreement actually is on this corpus.
                        if bot:WasRecentlyDamagedByCreep(G.SIT_ATTR_WINDOW) then
                            bump('deep_with_creep_damage')
                        end
                        out:write(string.format('F %s %s %.4f\n',
                            path:match('([^/]+)%.lua$'), u.name, nHP))
                    end

                    -- ⭐ THE CORRECTION TO `stop_source 8`.  Same slice
                    -- tests/_tpdeep_sweep.lua counted -- inside the '回复状态'
                    -- trigger, inside the deep band, nothing drinkable -- split by
                    -- the clauses THIS arm keeps.  8 says "no supply"; only
                    -- `stop_source_domain` says "and safe".
                    do
                        local nMP = J.GetMP(bot)
                        local bTrigger = (nHP + nMP < G.RECOVER_SUM_TRIGGER)
                            or (nHP < G.RECOVER_HP_TRIGGER)
                        if bTurbo and bTrigger and nHP < G.DEEP_FLOOR
                            and nHP >= G.TPDEEP_LOW_EDGE and not bMain
                        then
                            bump('trigger_deep_nosrc')
                            -- Order-free, for the same reason as `nosrc_attr_only`
                            -- above: `stop_source_attr` is a PREFIX bucket and its
                            -- zero is about the walk's order, not about the corpus.
                            if bAttr then bump('stop_source_attr_any') end
                            local sWhy
                            if bRingBusy then sWhy = 'ring'; bump('stop_source_ring')
                            elseif bAttr then sWhy = 'attr'; bump('stop_source_attr')
                            elseif bTower then sWhy = 'tower'; bump('stop_source_tower')
                            else sWhy = 'domain'; bump('stop_source_domain') end
                            out:write(string.format('S %s %s %.4f %s\n',
                                path:match('([^/]+)%.lua$'), u.name, nHP, sWhy))
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
