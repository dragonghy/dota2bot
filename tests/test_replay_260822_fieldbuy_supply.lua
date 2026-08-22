-- [fieldbuy / owner priority P2] The SUPPLY side: buy the salve.
--
-- P2 is "低血不回家 —— 买大药/野区回复替代 TP 回城". The decision side landed
-- on 2026-08-22 as 'stayfield' (the tpscroll 撤退:3 branch) and 'stayfield2'
-- (mode_retreat_generic). Both of them can only keep a bot in the field when
-- it ALREADY has something to drink: J.ShouldRegenNotGoHome's last clause is
-- J.HasFieldRegenSource. This file is the other half -- the frames where that
-- clause is what says no.
--
-- The corpus says that half is the bigger one. Of the 50 hero-frames (in 930)
-- that satisfy the whole situation predicate, 22 carry a heal and 28 do not.
-- Nothing in the repo buys for those 28:
--   * 'fieldregen' (item_purchase_generic, gated, already armed in the test
--     set) carries `not J.IsInLaningPhase()`, and Turbo's laning phase runs to
--     at least 8:00 of a ~20 minute game -- 18 of the 28 are below that floor,
--     where it is silent by construction rather than by threshold;
--   * the shipped in-lane re-supply block stops at `botLevel < 6`, and 22 of
--     the 28 are level 6 or above;
--   * 12 frames sit inside BOTH holes at once.
--   * 'fieldregen' also stops at HP < 0.45, which excludes 13 of the 28 --
--     including the owner's own pinned Slardar frame, at 46.0%.
-- Every one of those numbers comes from the sweep in _fieldbuy_supply_sweep.lua
-- driving the SHIPPED helpers over the real corpus, and is asserted below.
--
-- Two frames are pinned, chosen so that each isolates ONE of the two shipped
-- blockers rather than both at once:
--   * frame A (f_260820_102645_cm_es_reach, zuus t=391.5): level 7, 39.5% HP.
--     Under fieldregen's HP ceiling, so the ONLY thing keeping fieldregen quiet
--     is the laning clause; and over the in-lane block's level cap.
--   * frame B (f_260820_043637_axe_ring_alone, viper t=641.4): level 15, 54.9%
--     HP, past the laning phase. Here the laning clause is satisfied and the
--     ONLY blocker is fieldregen's 0.45 ceiling.
--
-- What this file can assert that the 'stayfield' half could not: the FINAL
-- ACTION. The item USAGE layer is structurally dark on a fixture (the
-- sixteenth world assertion, GH #100: J.CanCastAbility is false on all 5,774
-- occupied slots), but ItemPurchaseThink is a different entry point and it
-- runs. So the measurement here is the purchase itself --
-- ActionImmediate_PurchaseItem('item_flask') -- not a branch being reachable.
--
-- One negative result from the mutation battery, recorded rather than papered
-- over: removing the tower clause from J.IsFieldRegenSituation reddens ONLY
-- the corpus counter here. Neither pinned frame has an enemy tower within
-- 1,200, so that clause has no isolated behavioural witness in this file --
-- its witness lives in the sibling stayfield2 file, on the frame the clause
-- was born from (f_260819_142047_zuus_ult_denied). A green mutation is not a
-- pass; a mutation that only moves a counter is a counter with teeth and a
-- behaviour assertion that is missing.
--
-- Driving it needs three declarations a .dem cannot carry, and they are made
-- out loud in `drive_purchase` below rather than hidden in a helper. One of
-- them is a second instance of the fourteenth world assertion's shape (GH #91:
-- a lazily-initialised stamp compared against the clock that initialised it),
-- this time on the purchase entry point itself.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local ZUUS = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'
local VIPER = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local PURCHASE = 'bots/item_purchase_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- Install a fixture world with a chosen hero as the subject.
--- `armed` is the soak id to arm, or nil for the shipped world (all gates off).
local function world(path, hero, armed)
    local J, bot, heroes, fx = rf.load(path, hero)
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot, heroes, fx
end

local function hp_pct(bot) return bot:GetHealth() / bot:GetMaxHealth() end

local function dist(a, b) return GetUnitToUnitDistance(a, b) end

--- Put a named item into one of the subject's slots, keeping the rest of the
--- real inventory. Returns nothing; the world is mutated in place.
local function put_item(bot, slot, name)
    local slots = {}
    for i = 0, 16 do slots[i] = bot:GetItemInSlot(i) end
    slots[slot] = { GetName = function() return name end,
                    GetCurrentCharges = function() return 0 end }
    rawget(bot, '__spec').GetItemInSlot = function(_, i) return slots[i] end
    rawset(bot, 'GetItemInSlot', nil)
end

--- Move the subject's HP and CHECK that the move landed where the shipped
--- predicate reads it. J.GetHP reads OriginalGetHealth for a unit on the
--- reader's own team and GetHealth otherwise, so writing only one of them
--- produces a mutation that runs, is green, and measures nothing -- the
--- failure shape the charter records as "a mutation is not a mutation until
--- it moves the measured quantity". Asserted, not assumed.
local function set_hp(J, bot, pct)
    local spec = rawget(bot, '__spec')
    local n = math.floor(bot:GetMaxHealth() * pct)
    spec.GetHealth = n
    spec.OriginalGetHealth = n
    rawset(bot, 'GetHealth', nil)
    rawset(bot, 'OriginalGetHealth', nil)
    assert(math.abs(J.GetHP(bot) - pct) < 0.01,
        'the HP mutation did not reach J.GetHP: asked ' .. pct .. ', reads ' .. J.GetHP(bot))
end

--- Drive the real ItemPurchaseThink on the installed frame and return the list
--- of items it tried to buy, plus whether Think ran to completion.
---
--- THREE DECLARATIONS, all of them things a .dem does not carry, all of them
--- made here so they are one visible line in the test rather than a loader
--- default (the GH #61 ruling):
---   (1) GetGameState. The mock resolves unknown ALL_CAPS globals to sentinel
---       integers and Get* to 0, so the shipped guard at the top of Think
---       (`GetGameState() ~= GAME_STATE_PRE_GAME and ~= GAME_STATE_GAME_IN_PROGRESS
---       -> return`) refuses every fixture. Declared: the game is in progress.
---   (2) bot.lastItemPurchaseFrameProcessTime. Think stamps it on first sight
---       and then compares `currentTime - stamp < 1 -> return`, so in a VM that
---       lives for one call the first reader IS its own initialiser and the
---       difference is exactly 0. That is the fourteenth world assertion's
---       shape (GH #91, mode_farm_generic's defendPings) on a second, entirely
---       different entry point. Declared: this bot has been ticking for a while.
---   (3) the item stock. GetItemStockCount is an engine query with no fixture
---       field; declared plentiful.
--- NOT declared, and therefore NOT exercised, stated because it matters: the
--- gold clause. The mock's GetItemCost answers 0, so `botGold >= cost` is
--- vacuously true here no matter what gold is set to. This file does not claim
--- to have tested it.
local function drive_purchase(bot)
    local spec = rawget(bot, '__spec')
    local bought = {}
    spec.ActionImmediate_PurchaseItem = function(_, name) bought[#bought + 1] = name end
    rawset(bot, 'ActionImmediate_PurchaseItem', nil)
    GetGameState = function() return GAME_STATE_GAME_IN_PROGRESS end -- luacheck: ignore
    GetItemStockCount = function() return 10 end                     -- luacheck: ignore
    rawset(bot, 'lastItemPurchaseFrameProcessTime', DotaTime() - 5)

    ItemPurchaseThink = nil -- luacheck: ignore
    assert(pcall(dofile, PURCHASE), 'item_purchase_generic failed to load')
    assert(type(ItemPurchaseThink) == 'function', 'ItemPurchaseThink not defined')
    local ran = pcall(ItemPurchaseThink)
    ItemPurchaseThink = nil -- luacheck: ignore
    -- Put the world back. run_tests.lua runs every test file in ONE process,
    -- and these two are answered by the mock's _G metatable until somebody
    -- writes a real key over it -- so leaving them set would hand every later
    -- test file a world where the game is in progress and every item is in
    -- stock. That is the M16 leak (GH #93's file caught itself doing it), and
    -- the assertion below states what successors actually inherit.
    GetGameState = nil      -- luacheck: ignore
    GetItemStockCount = nil -- luacheck: ignore
    return bought, ran
end

local function has(list, name)
    for _, v in ipairs(list) do if v == name then return true end end
    return false
end

-- ---------------------------------------------------------------------------
-- Frame A: 20260820_102645, zuus t=391.5. Level 7, 360/911 = 39.5% HP, nearest
-- enemy (viper) 1,727 units away, no enemy tower within 1,200, nothing hit him
-- inside the 3s window. His six usable slots hold arcane_boots, an EMPTY
-- bottle and a magic_wand.

tests['frame A: a level-7 zeus at 39.5% with nothing he can drink'] = function()
    local J, bot, heroes = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus', 'subject is Zeus')
    assert(math.abs(hp_pct(bot) - 0.3952) < 0.001,
        '39.5% HP (360/911), saw ' .. hp_pct(bot))
    assert(bot:GetLevel() == 7, 'level 7, saw ' .. bot:GetLevel())
    -- MARGIN, stated because it is thin: 1,727 against a 1,600 ring is 127
    -- units. If a dumper change moves the sampling phase (GH #107) this frame
    -- can leave the domain on that alone.
    local d = dist(bot, heroes['npc_dota_hero_viper'])
    assert(d > 1700 and d < 1760, 'nearest enemy 1,727 away, saw ' .. math.floor(d))
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'no enemy tower in reach')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false, 'nothing hit him recently')
end

tests['frame A: the bottle he carries is the empty entity, not an empty bottle'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    -- The helper's comment claims a fixture can never answer TRUE through the
    -- bottle leg. This frame is the real-frame witness for WHY: the replay
    -- carries the class name, and a bottle with no charges is a different item
    -- entirely, so the name test rejects it before the charge test is reached.
    assert(bot:GetItemInSlot(4):GetName() == 'item_empty_bottle',
        'slot 4 is the empty-bottle entity')
    assert(J.HasFieldRegenSource(bot) == false,
        'arcane_boots + empty_bottle + magic_wand is nothing drinkable')
end

tests['frame A, gate OFF: the helper is inert'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', nil)
    assert(J.ShouldBuyFieldRegen(bot) == false,
        'no candidate armed -> the supply lever does not exist')
    -- and the situation underneath it is unchanged, i.e. the gate is the only
    -- thing that moved.
    assert(J.IsFieldRegenSituation(bot) == true, 'the frame itself still qualifies')
end

tests['frame A, gate ON: buy him a salve'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    assert(J.ShouldBuyFieldRegen(bot) == true,
        'hurt, alone, no tower, nothing to drink -> this is the supply frame')
end

tests['frame A: the bag clause is the one doing the work, inverted'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    -- Give him a tango in a USABLE slot and the supply lever must switch off
    -- while the decision lever switches on. Same frame, same predicate, the
    -- two halves trading places -- which is the whole design claim.
    assert(J.ShouldRegenNotGoHome(bot) == false, 'before: nothing to drink')
    put_item(bot, 3, 'item_tango')
    assert(J.HasFieldRegenSource(bot) == true, 'sanity: the tango is usable')
    assert(J.ShouldBuyFieldRegen(bot) == false, 'he has one now -- do not buy')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'and now the stayfield half owns the frame')
end

tests['frame A: a backpack heal does not switch it off'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    put_item(bot, 7, 'item_flask')
    assert(bot:GetItemInSlot(7):GetName() == 'item_flask', 'sanity: it is in the backpack')
    assert(J.HasFieldRegenSource(bot) == false, 'a salve in the backpack cannot be drunk')
    assert(J.ShouldBuyFieldRegen(bot) == true,
        'the helper still says buy -- the call site is what refuses to '
        .. 'double-buy, and that is asserted separately below')
end

tests['frame A: an enemy inside the ring closes it'] = function()
    local J, bot, heroes = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    local viper = heroes['npc_dota_hero_viper']
    local v = bot:GetLocation()
    rawget(viper, '__spec').GetLocation = Vector(v.x + 900, v.y, v.z or 0)
    rawset(viper, 'GetLocation', nil)
    assert(dist(bot, viper) < 1600, 'sanity: viper is now inside the ring')
    assert(J.IsFieldRegenSituation(bot) == false, 'somebody is on him')
    assert(J.ShouldBuyFieldRegen(bot) == false, 'shopping is not the answer to that')
end

tests['frame A: both edges of the HP band are live on this frame'] = function()
    local J, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    set_hp(J, bot, 0.70)
    assert(J.ShouldBuyFieldRegen(bot) == false, 'healthy enough not to care')
    set_hp(J, bot, 0.10)
    assert(J.ShouldBuyFieldRegen(bot) == false,
        'below the floor the genuine escape retreat stands, and a salve is not it')
    set_hp(J, bot, 0.3952)
    assert(J.ShouldBuyFieldRegen(bot) == true, 'restored: the frame qualifies again')
end

tests['frame A, FINAL ACTION: armed, ItemPurchaseThink buys the flask'] = function()
    local _, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    local bought = drive_purchase(bot)
    assert(has(bought, 'item_flask'),
        'the real purchase entry point buys a salve on this frame, saw: '
        .. table.concat(bought, ','))
end

tests['frame A, FINAL ACTION: unarmed, it does not'] = function()
    local _, bot = world(ZUUS, 'npc_dota_hero_zuus', nil)
    local bought = drive_purchase(bot)
    assert(not has(bought, 'item_flask'),
        'shipped world: no salve is bought on this frame, saw: '
        .. table.concat(bought, ','))
    -- Negative control with teeth: the drive is not silently doing nothing.
    -- Think still buys the things it buys on this frame in the shipped world.
    assert(#bought > 0, 'the drive is live -- Think bought something else')
end

-- ---------------------------------------------------------------------------
-- Frame B: 20260820_043637, viper t=641.4. Level 15, 923/1681 = 54.9% HP, past
-- the laning phase, nearest enemy 5,458 units away. Here 'fieldregen' clears
-- its laning clause and is stopped by its HP ceiling alone.

tests['frame B: past the laning phase, and above fieldregen\'s ceiling'] = function()
    local J, bot, heroes = world(VIPER, 'npc_dota_hero_viper', 'fieldbuy')
    assert(bot:GetLevel() == 15, 'level 15, saw ' .. bot:GetLevel())
    assert(math.abs(hp_pct(bot) - 0.5491) < 0.001,
        '54.9% HP (923/1681), saw ' .. hp_pct(bot))
    assert(J.IsInLaningPhase() == false,
        'the laning clause that silences fieldregen is SATISFIED here')
    assert(hp_pct(bot) > 0.45,
        'so the only shipped blocker left is the 0.45 ceiling, and he is above it')
    assert(dist(bot, heroes['npc_dota_hero_skywrath_mage']) > 5000,
        'nearest enemy is 5,458 away -- nobody is contesting this')
end

tests['frame B: the faerie_fire he owns is in the backpack'] = function()
    local J, bot = world(VIPER, 'npc_dota_hero_viper', 'fieldbuy')
    assert(bot:GetItemInSlot(6):GetName() == 'item_faerie_fire',
        'slot 6 is a backpack slot')
    assert(J.HasFieldRegenSource(bot) == false,
        'six usable slots, none of them a heal -- swapping costs six seconds')
    assert(J.ShouldBuyFieldRegen(bot) == true, 'so this frame is in the domain')
end

tests['frame B, FINAL ACTION: armed buys, unarmed does not'] = function()
    local _, bot = world(VIPER, 'npc_dota_hero_viper', 'fieldbuy')
    local boughtOn = drive_purchase(bot)
    local _, bot2 = world(VIPER, 'npc_dota_hero_viper', nil)
    local boughtOff = drive_purchase(bot2)
    assert(has(boughtOn, 'item_flask'), 'armed: saw ' .. table.concat(boughtOn, ','))
    assert(not has(boughtOff, 'item_flask'), 'shipped: saw ' .. table.concat(boughtOff, ','))
end

tests['frame B: the call site refuses to double-buy'] = function()
    local J, bot = world(VIPER, 'npc_dota_hero_viper', 'fieldbuy')
    put_item(bot, 7, 'item_flask')
    assert(J.ShouldBuyFieldRegen(bot) == true,
        'the helper only reads the six usable slots, so it still says yes')
    local bought = drive_purchase(bot)
    assert(not has(bought, 'item_flask'),
        'but the call site checks FindItemSlot across the whole inventory: '
        .. 'saw ' .. table.concat(bought, ','))
end

-- ---------------------------------------------------------------------------
-- [recorded] What driving the purchase layer on a fixture actually costs.

tests['[recorded] ItemPurchaseThink crashes downstream of the purchase, and why'] = function()
    local _, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    local bought, ran = drive_purchase(bot)
    -- The purchase this file measures happens well before the crash, so the
    -- assertion above is on a real prefix of Think, not on a completed run.
    -- Saying so here rather than swallowing it: Think does NOT run to the end
    -- on this frame.
    assert(ran == false, 'Think does not complete on this frame')
    assert(has(bought, 'item_flask'), 'and the flask purchase is upstream of that')
    -- The cause, pinned so it cannot rot into folklore: an unstubbed engine
    -- API. This is a NEW unrunnable surface, in the family the sixteenth world
    -- assertion catalogued (GH #100).
    assert(bot:DistanceFromSecretShop() == nil,
        'bot:DistanceFromSecretShop() has no mock -- it answers nil')
    -- And it is reached only because of the FIFTEENTH world assertion (GH #93):
    -- the guard above that call is `GetGameMode() ~= 23 and botLevel > 6`,
    -- which the fixture world reads TRUE because the mode is Turbo BY NAME and
    -- not by the literal 23. An honest-23 world takes the other leg, which
    -- needs level > 9 -- so this crash is a spelling artefact for every hero
    -- of level 7, 8 or 9.
    local src = read_file(PURCHASE)
    assert(src:find('GetGameMode() ~= 23 and botLevel > 6', 1, true),
        'the guard in front of DistanceFromSecretShop changed shape')
end

tests['[recorded] what the next test file inherits from this one'] = function()
    local _, bot = world(ZUUS, 'npc_dota_hero_zuus', 'fieldbuy')
    drive_purchase(bot)
    -- The two world declarations are gone again: rawget, because a plain read
    -- would be answered by the mock's metatable and could not tell "restored"
    -- from "still set".
    assert(rawget(_G, 'GetGameState') == nil,
        'GetGameState leaked out of this file')
    assert(rawget(_G, 'GetItemStockCount') == nil,
        'GetItemStockCount leaked out of this file')
    -- What DOES survive, said out loud rather than left as a surprise: loading
    -- item_purchase_generic defines its own file-level globals, exactly as any
    -- test that drives that file does. They are the shipped file's own names,
    -- not a changed world reading.
    assert(type(rawget(_G, 'IsThereHealingInStash')) == 'function',
        'item_purchase_generic own globals stay defined, as after any drive')
end

tests['[recorded] the corpus census behind this lever'] = function()
    local p = assert(io.popen('lua5.1 tests/_fieldbuy_supply_sweep.lua 2>&1'))
    local out = p:read('*a')
    p:close()
    assert(out:find('\nDONE', 1, true) or out:sub(1, 5) == 'DONE\n',
        'the sweep subprocess did not finish:\n' .. out:sub(1, 800))
    local C = {}
    for k, v in out:gmatch('\nC (%S+) (%-?%d+)') do C[k] = tonumber(v) end
    local K = {}
    for k, v in out:gmatch('CONST (%S+) ([%d%.]+)') do K[k] = tonumber(v) end

    -- The constants the census reasons about, read from the shipped source by
    -- the sweep itself (the M13 rule: a census that restates the constant it
    -- measures reports the old world unmoved).
    assert(K.band_lo == 0.18 and K.band_hi == 0.55, 'the family HP band moved')
    assert(K.fr_ceiling == 0.45, "fieldregen's HP ceiling moved")
    assert(K.lane_level_cap == 6, 'the in-lane re-supply level cap moved')
    assert(K.turbo_lane_floor == 480, "Turbo's hard laning floor moved")

    assert(C.err == 0, 'every hero-frame drove without error, saw ' .. tostring(C.err))
    assert(C.fixtures == 100 and C.live == 930,
        'corpus size moved: ' .. tostring(C.fixtures) .. '/' .. tostring(C.live))
    assert(C.band == 150, 'frames in the HP band: ' .. tostring(C.band))
    assert(C.band_noheal == 82,
        'and 82 of those carry nothing drinkable -- the raw shape of the '
        .. 'supply problem, saw ' .. tostring(C.band_noheal))
    assert(C.situation == 50, 'frames satisfying the situation: ' .. tostring(C.situation))
    -- THE headline: the half nothing was managing is the bigger half.
    assert(C.stayfield_domain == 22, "stayfield's domain: " .. tostring(C.stayfield_domain))
    assert(C.gap == 28, "fieldbuy's domain: " .. tostring(C.gap))
    assert(C.gap > C.stayfield_domain,
        'the supply gap is larger than the domain it complements')
    assert(C.situation == C.stayfield_domain + C.gap,
        'and the two halves partition the situation exactly -- if this ever '
        .. 'fails, the two helpers have drifted apart')

    -- Corpus-wide inertness, not just on the pinned frames.
    assert(C.gap_gate_off == 0,
        'with no candidate armed the lever is false on all 930 frames, saw '
        .. tostring(C.gap_gate_off))

    -- Why the shipped paths do not reach it.
    assert(C.gap_hard_laning == 18,
        'inside the net-worth-independent laning floor where fieldregen is '
        .. 'silent by construction: ' .. tostring(C.gap_hard_laning))
    assert(C.gap_level_ge_cap == 22,
        'at or above the in-lane block level cap: ' .. tostring(C.gap_level_ge_cap))
    assert(C.gap_both_holes == 12, 'inside both holes at once: ' .. tostring(C.gap_both_holes))
    assert(C.gap - C.gap_under_fr_ceiling == 13,
        "above fieldregen's HP ceiling: " .. tostring(C.gap - C.gap_under_fr_ceiling))

    -- What the purchase call site can actually act on. NOT the same number as
    -- the domain, and the difference is the point: one frame is already under
    -- modifier_flask_healing (a hero mid-salve reads as "nothing in a usable
    -- slot" because the salve is consumed), and two own a flask or tango
    -- somewhere in the inventory.
    assert(C.gap_already_healing == 1, 'already drinking: ' .. tostring(C.gap_already_healing))
    assert(C.gap_buyable == 25, 'frames the call site would buy on: ' .. tostring(C.gap_buyable))
end

-- ---------------------------------------------------------------------------
-- [reverse] Source pins. Charter rule: a gated fix is not shipped, and a
-- comment claiming a gate that does not exist is worse than no comment.

tests['[reverse] the lever is gated, and gated on its own id'] = function()
    local src = read_file(JMZ)
    local at = assert(src:find('function J.ShouldBuyFieldRegen', 1, true),
        'J.ShouldBuyFieldRegen moved')
    local body = src:sub(at, at + 400)
    assert(body:find("J.IsSoakCandidate( 'fieldbuy' )", 1, true),
        'the gate is the first thing the wrapper does')
    -- and it is a NEW id, not a rider on an armed one.
    local _, nStay = src:gsub("IsSoakCandidate%( 'stayfield' %)", '')
    local _, nStay2 = src:gsub("IsSoakCandidate%( 'stayfield2' %)", '')
    local _, nBuy = src:gsub("IsSoakCandidate%( 'fieldbuy' %)", '')
    assert(nStay == 1 and nStay2 == 1 and nBuy == 1,
        'each half of the family carries exactly one gate: '
        .. nStay .. '/' .. nStay2 .. '/' .. nBuy)
end

tests['[reverse] the core situation predicate has no ungated callers'] = function()
    local src = read_file(JMZ)
    -- Counted as CODE, not as mentions: prose about the helper is free, a call
    -- to it is not. Exactly one definition and exactly two calls -- from
    -- ShouldRegenNotGoHome and from ShouldBuyFieldRegen, both of which carry a
    -- gate above them. A third call is a caller that has to be checked by
    -- hand, because an ungated one ships the behaviour.
    local _, nDef = src:gsub('function J%.IsFieldRegenSituation%(', '')
    local _, nCode = src:gsub('J%.IsFieldRegenSituation%(', '')
    assert(nDef == 1, 'definitions of J.IsFieldRegenSituation: ' .. nDef)
    assert(nCode - nDef == 2, 'call sites of J.IsFieldRegenSituation: ' .. (nCode - nDef))
    local p = assert(io.popen('grep -rl "IsFieldRegenSituation" bots/ | sort'))
    local files = p:read('*a')
    p:close()
    assert(files == 'bots/FunLib/jmz_func.lua\n',
        'the core predicate escaped jmz_func: ' .. files)
end

tests['[reverse] fieldregen was not touched'] = function()
    -- The reason this lever is a new id at all: 'fieldregen' is armed in the
    -- current test set, so widening it would silently change what a wave in
    -- flight is measuring. If a later round does widen it, this pin should be
    -- retired deliberately rather than quietly.
    local src = read_file(PURCHASE)
    local at = assert(src:find("J.IsSoakCandidate('fieldregen')", 1, true),
        'the fieldregen block moved')
    local body = src:sub(at, at + 1200)
    assert(body:find('not J.IsInLaningPhase()', 1, true), 'its laning clause is intact')
    assert(body:find('J.GetHP(bot) < 0.45', 1, true), 'its HP ceiling is intact')
end

tests['[reverse] the purchase call site is guarded by the helper'] = function()
    local src = read_file(PURCHASE)
    local at = assert(src:find('J.ShouldBuyFieldRegen(bot)', 1, true),
        'the fieldbuy call site moved')
    local body = src:sub(at, at + 700)
    assert(body:find("bot:ActionImmediate_PurchaseItem('item_flask')", 1, true),
        'the guarded action is the salve purchase')
    -- The two clauses this file asserts behaviourally, pinned as source too,
    -- so a refactor cannot drop them without a red.
    assert(body:find("bot:FindItemSlot('item_flask') < 0", 1, true),
        'the double-buy guard on flask is present')
    assert(body:find("bot:FindItemSlot('item_tango') < 0", 1, true),
        'the double-buy guard on tango is present')
end

return tests
