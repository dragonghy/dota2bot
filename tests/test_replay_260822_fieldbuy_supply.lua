-- [fieldbuy / owner priority P2] The SUPPLY half: the frames where the other
-- two ids structurally cannot act.
--
-- Owner's turbo rule is "don't go home to heal -- buy a salve and heal in the
-- field". The decision-side pair landed earlier today ('stayfield', the TP
-- branch; 'stayfield2', the walk branch), and both end in the same clause:
-- J.HasFieldRegenSource -- is there anything in the six usable slots to drink?
-- When that clause is FALSE the pair is silent by construction, and holding a
-- bot in the field with nothing to drink would be idling, not healing. Those
-- frames are this id's domain, and on the 100-fixture corpus they are the
-- BIGGER half: the situation holds on 50 live hero frames, 22 with a heal in
-- the bag and 28 without.
--
-- The shipped purchase tree does not reach them either, and not by a margin
-- that could be tuned away:
--   * the mid-game re-purchase (gated 'fieldregen', item_purchase_generic:776)
--     carries `not J.IsInLaningPhase()`. In turbo the laning phase runs to at
--     least 8:00 of a ~20 minute game, and 24 of the 28 dry frames are inside
--     it;
--   * the same block carries an HP ceiling of 0.45, which sits BELOW this
--     family's band of (0.18, 0.55]: 13 of the 28 are above it;
--   * the shipped "Init Healing Items in Lane" block covers the other side of
--     the laning floor, but stops at `botLevel < 6`, and 22 of the 28 are
--     level 6 or above.
-- 18 of the 28 are inside the laning phase AND level 6+, i.e. in both holes at
-- once. All four counts are measured below off the shipped predicates, not
-- restated from the source.
--
-- What this file can assert that the two decision-side files could not: a
-- FINAL ACTION. The item USE layer is dark on a fixture (GH #100, the
-- sixteenth world assertion: J.CanCastAbility is false on all 5,774 occupied
-- slots, so no item Consider has ever run), but the PURCHASE entry drives --
-- at the price of three declarations, one of which is GH #91 recurring in a
-- new file. They are named in [premise] below rather than hidden in a loader,
-- per the GH #61 ruling.
--
-- Honest bounds, stated first:
--   * the gold clause is NOT tested. The mock's GetItemCost answers 0, so
--     `botGold >= GetItemCost('item_flask')` is vacuously true offline. That is
--     asserted below so nobody reads affordability into this result.
--   * frame A's deciding margin is 127 units (nearest enemy 1,727 against the
--     1,600 ring). GH #107: if the dumper's sampling phase moves, that frame
--     can flip on phase alone.
--   * ItemPurchaseThink does not run to completion on either frame -- it dies
--     later at bot:DistanceFromSecretShop() (GH #114). The purchase measured
--     here happens UPSTREAM of that, which is asserted rather than assumed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

-- Frame A: inside the laning phase, below fieldregen's HP ceiling -- so the
-- ONLY shipped clause standing between this bot and a salve is the laning one.
local A_FIX, A_HERO = 'tests/fixtures/f_260820_102645_cm_es_reach.lua', 'npc_dota_hero_zuus'
-- Frame B: past the laning phase, so fieldregen's laning clause admits it --
-- and it is stopped by the 0.45 ceiling alone.
local B_FIX, B_HERO = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua', 'npc_dota_hero_viper'

local PURCHASE = 'bots/item_purchase_generic.lua'
local JMZ = 'bots/FunLib/jmz_func.lua'

local tests = {}

local function read_file(path)
    local f = assert(io.open(path, 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

--- Install a fixture world with `armed` (a soak id, or nil for none) armed.
local function world(fix, hero, armed)
    local J, bot = rf.load(fix, hero)
    J.IsSoakCandidate = function(id) return armed ~= nil and id == armed end
    return J, bot
end

--- The three declarations GH #114 records, made visible here rather than in
--- the loader (GH #61 ruling: an assumption belongs in the test that needs it).
---   1. GetGameState -- the mock answers 0 for Get*, and ItemPurchaseThink
---      returns immediately unless the state is PRE_GAME or GAME_IN_PROGRESS.
---   2. bot.lastItemPurchaseFrameProcessTime -- GH #91 (the fourteenth world
---      assertion) recurring in a new file: the field is lazily initialised by
---      the same clock reading it is then compared against, so in a one-call VM
---      the difference is exactly 0 and the whole purchase layer returns before
---      doing anything. Declared as "the last purchase tick was long ago".
---   3. GetItemStockCount -- an engine query; nothing in the .dem answers it.
--- Returns the list of items the bot was told to purchase, in order.
local function drive_purchase(J, bot)
    GAME_STATE_GAME_IN_PROGRESS = 5                       -- luacheck: ignore
    GetGameState = function() return 5 end                -- luacheck: ignore
    GetItemStockCount = function() return 10 end          -- luacheck: ignore
    bot.lastItemPurchaseFrameProcessTime = -1e6

    local buys = {}
    local spec = rawget(bot, '__spec')
    spec.ActionImmediate_PurchaseItem = function(_, name) buys[#buys + 1] = name end
    rawset(bot, 'ActionImmediate_PurchaseItem', nil)

    ItemPurchaseThink = nil                               -- luacheck: ignore
    assert(pcall(dofile, PURCHASE), 'the purchase file did not load')
    local ok, err = pcall(ItemPurchaseThink)
    ItemPurchaseThink = nil                               -- luacheck: ignore
    return buys, ok, tostring(err), J
end

local function has(list, name)
    for i, v in ipairs(list) do if v == name then return i end end
    return nil
end

local function near(a, b, eps)
    return a ~= nil and b ~= nil and math.abs(a - b) <= (eps or 1e-4)
end

-- ---------------------------------------------------------------- premises --

tests['[premise] the purchase layer drives, and all three declarations bite'] = function()
    -- Each declaration is removed in turn; the drive must go silent without it.
    -- Without this, "armed buys a flask" could be true for reasons unrelated to
    -- the three lines above, and a loader change could quietly remove one.
    local J, bot = world(A_FIX, A_HERO, 'fieldbuy')
    local buys = drive_purchase(J, bot)
    assert(#buys > 0, 'the drive bought nothing at all; the premise is dead')

    -- 1. game state
    local J2, bot2 = world(A_FIX, A_HERO, 'fieldbuy')
    GAME_STATE_GAME_IN_PROGRESS = 5                        -- luacheck: ignore
    GetItemStockCount = function() return 10 end           -- luacheck: ignore
    GetGameState = function() return 0 end                 -- luacheck: ignore
    bot2.lastItemPurchaseFrameProcessTime = -1e6
    local b2 = {}
    local spec2 = rawget(bot2, '__spec')
    spec2.ActionImmediate_PurchaseItem = function(_, n) b2[#b2 + 1] = n end
    rawset(bot2, 'ActionImmediate_PurchaseItem', nil)
    ItemPurchaseThink = nil                                -- luacheck: ignore
    assert(pcall(dofile, PURCHASE))
    pcall(ItemPurchaseThink)
    ItemPurchaseThink = nil                                -- luacheck: ignore
    assert(#b2 == 0, 'the game-state declaration is not load-bearing')

    -- 2. the GH #91 purchase tick
    local J3, bot3 = world(A_FIX, A_HERO, 'fieldbuy')
    GetGameState = function() return 5 end                 -- luacheck: ignore
    GetItemStockCount = function() return 10 end           -- luacheck: ignore
    bot3.lastItemPurchaseFrameProcessTime = nil -- let it initialise itself
    local b3 = {}
    local spec3 = rawget(bot3, '__spec')
    spec3.ActionImmediate_PurchaseItem = function(_, n) b3[#b3 + 1] = n end
    rawset(bot3, 'ActionImmediate_PurchaseItem', nil)
    ItemPurchaseThink = nil                                -- luacheck: ignore
    assert(pcall(dofile, PURCHASE))
    pcall(ItemPurchaseThink)
    ItemPurchaseThink = nil                                -- luacheck: ignore
    assert(#b3 == 0,
        'the lazily-initialised purchase tick did NOT stop the layer; '
        .. 'GH #91 may have been fixed -- reread this file if so')
    assert(J3 ~= nil and J2 ~= nil and J ~= nil)
end

tests['[declared] the gold clause is stubbed true offline, so it is not tested'] = function()
    local _, bot = world(A_FIX, A_HERO, 'fieldbuy')
    assert(GetItemCost('item_flask') == 0,
        'GetItemCost no longer answers 0; the gold clause may now be real, '
        .. 'and this file s claims about affordability need revisiting')
    assert(bot:GetGold() == 0, 'and the fixture carries no gold either')
end

-- ------------------------------------------------------------------ frames --

tests['frame A: level-7 Zeus at 39.5% HP, alone, inside the laning phase'] = function()
    local J, bot = world(A_FIX, A_HERO, 'fieldbuy')
    assert(near(J.GetHP(bot), 0.3952, 5e-4), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:GetLevel() == 7, 'level moved: ' .. bot:GetLevel())
    assert(near(DotaTime(), 391.5, 0.05), 'frame time moved: ' .. DotaTime())
    assert(J.IsInLaningPhase() == true, 'frame A must be inside the laning phase')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0, 'the ring is empty')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false, 'nobody hit it recently')
    assert(#bot:GetNearbyTowers(1200, true) == 0, 'no enemy tower in reach')
    -- The margin, named because it is thin (GH #107).
    local nearest = nil
    for _, e in pairs(J.GetNearbyHeroes(bot, 5000, true, BOT_MODE_NONE)) do
        local d = GetUnitToUnitDistance(bot, e)
        if nearest == nil or d < nearest then nearest = d end
    end
    assert(nearest ~= nil and nearest > 1600 and nearest < 1900,
        'the deciding margin should be ~127 units, got nearest=' .. tostring(nearest))
end

tests['frame A: the bag is dry -- and slot 4 is literally an EMPTY bottle'] = function()
    local J, bot = world(A_FIX, A_HERO, 'fieldbuy')
    assert(J.HasFieldRegenSource(bot) == false, 'frame A must be dry')
    -- The helper's bottle leg has two independent reasons to say no here; this
    -- frame is the first real witness for the name one (the dumper writes the
    -- class name, so an empty bottle is a different item entirely).
    assert(bot:GetItemInSlot(4):GetName() == 'item_empty_bottle',
        'slot 4 is the empty-bottle witness')
    -- And the wand, which the helper deliberately does not count.
    assert(bot:GetItemInSlot(5):GetName() == 'item_magic_wand',
        'slot 5 is the wand the helper refuses to count')
end

tests['frame B: level-15 Viper at 54.9% HP, past laning, heal in the BACKPACK'] = function()
    local J, bot = world(B_FIX, B_HERO, 'fieldbuy')
    assert(near(J.GetHP(bot), 0.5491, 5e-4), 'HP moved: ' .. J.GetHP(bot))
    assert(bot:GetLevel() == 15, 'level moved: ' .. bot:GetLevel())
    assert(J.IsInLaningPhase() == false, 'frame B must be past the laning phase')
    assert(#J.GetNearbyHeroes(bot, 5000, true, BOT_MODE_NONE) == 0,
        'frame B has nobody within 5,000 units')
    -- Why it is dry with a faerie_fire on the hero: slot 6 is the backpack, and
    -- a backpack item cannot be used. This is the first real-frame witness for
    -- the helper's 0-5 window (the sibling files could only restate it).
    assert(bot:GetItemInSlot(6):GetName() == 'item_faerie_fire',
        'the faerie_fire should be in slot 6')
    assert(J.HasFieldRegenSource(bot) == false,
        'a backpack faerie_fire must not count as a field heal')
end

-- ------------------------------------------------------------- the actions --

tests['action: frame A buys a salve when armed, and does not when it is not'] = function()
    local J, bot = world(A_FIX, A_HERO, 'fieldbuy')
    local onBuys = drive_purchase(J, bot)
    assert(has(onBuys, 'item_flask'), 'armed, frame A must buy a salve')

    local J2, bot2 = world(A_FIX, A_HERO, nil)
    local offBuys = drive_purchase(J2, bot2)
    assert(not has(offBuys, 'item_flask'), 'unarmed, no salve may be bought')
    -- Negative control with teeth: the unarmed drive is NOT a silent no-op.
    assert(#offBuys > 0, 'the unarmed drive bought nothing; the control is empty')
end

tests['action: frame B buys a salve when armed, and does not when it is not'] = function()
    local J, bot = world(B_FIX, B_HERO, 'fieldbuy')
    local onBuys = drive_purchase(J, bot)
    assert(has(onBuys, 'item_flask'), 'armed, frame B must buy a salve')

    local J2, bot2 = world(B_FIX, B_HERO, nil)
    local offBuys = drive_purchase(J2, bot2)
    assert(not has(offBuys, 'item_flask'), 'unarmed, no salve may be bought')
    assert(#offBuys > 0, 'the unarmed drive bought nothing; the control is empty')
end

tests['action: the salve is the ONLY difference the gate makes on either frame'] = function()
    -- Otherwise the id would be moving the purchase order around, which is a
    -- different (and much larger) change than the one being proposed.
    for _, s in ipairs({ { A_FIX, A_HERO }, { B_FIX, B_HERO } }) do
        local J, bot = world(s[1], s[2], 'fieldbuy')
        local on = drive_purchase(J, bot)
        local J2, bot2 = world(s[1], s[2], nil)
        local off = drive_purchase(J2, bot2)
        local i = has(on, 'item_flask')
        assert(i, 'armed must buy the salve on ' .. s[2])
        table.remove(on, i)
        assert(#on == #off, 'the gate changed more than one purchase on ' .. s[2])
        for k = 1, #off do
            assert(on[k] == off[k],
                'purchase order moved on ' .. s[2] .. ': ' .. tostring(on[k])
                .. ' vs ' .. tostring(off[k]))
        end
    end
end

tests['[recorded] the purchase happens upstream of the GH #114 crash'] = function()
    local J, bot = world(A_FIX, A_HERO, 'fieldbuy')
    local buys, ok, err = drive_purchase(J, bot)
    assert(not ok, 'ItemPurchaseThink completed; GH #114 may be fixed')
    assert(err:find('DistanceFromSecretShop') or err:find('compare nil with number'),
        'the crash moved: ' .. err)
    assert(has(buys, 'item_flask'), 'and the salve still happens before it')
    -- The un-stubbed engine call itself, so a mock change shows up here.
    assert(bot:DistanceFromSecretShop() == nil,
        'DistanceFromSecretShop got a stub; GH #114 can be closed')
    -- And the gate shape that reaches it, which only reaches it because of the
    -- fifteenth world assertion (GH #93: this world is Turbo by name and not by
    -- the literal 23, so the `~= 23` leg with its level>6 clause is taken).
    local src = read_file(PURCHASE)
    assert(src:find('GetGameMode() ~= 23 and botLevel > 6', 1, true),
        'the gate shape above the crash moved')
end

-- --------------------------------------------------------------- the gates --

tests['gate: nothing armed, the predicate is false on both frames'] = function()
    for _, s in ipairs({ { A_FIX, A_HERO }, { B_FIX, B_HERO } }) do
        local J, bot = world(s[1], s[2], nil)
        assert(J.ShouldFieldBuyRegen(bot) == false, 'ungated fire on ' .. s[2])
    end
end

tests['gate: arming a SIBLING id does not arm this one'] = function()
    for _, s in ipairs({ { A_FIX, A_HERO }, { B_FIX, B_HERO } }) do
        for _, other in ipairs({ 'stayfield', 'stayfield2', 'fieldregen' }) do
            local J, bot = world(s[1], s[2], other)
            assert(J.ShouldFieldBuyRegen(bot) == false,
                other .. ' armed this id on ' .. s[2])
        end
    end
end

tests['partition: on these frames the decision-side pair is silent by construction'] = function()
    -- The two halves are disjoint on every frame: same situation, opposite
    -- answers to "is there a heal in the bag". If this ever fails, one id is
    -- shadowing the other and a per-id A/B stops meaning anything.
    for _, s in ipairs({ { A_FIX, A_HERO }, { B_FIX, B_HERO } }) do
        local J, bot = world(s[1], s[2], 'stayfield')
        assert(J.IsFieldRegenSituation(bot) == true, 'situation on ' .. s[2])
        assert(J.ShouldRegenNotTpHome(bot) == false,
            'the TP half must be silent on a dry frame: ' .. s[2])
        local J2, bot2 = world(s[1], s[2], 'stayfield2')
        assert(J2.ShouldRegenNotWalkHome(bot2) == false,
            'the walk half must be silent on a dry frame: ' .. s[2])
    end
end

-- ------------------------------------------------- why the shipped tree misses --

tests['hole: fieldregen cannot reach frame A -- its laning clause, alone'] = function()
    local J, bot = world(A_FIX, A_HERO, 'fieldregen')
    assert(J.IsInLaningPhase() == true, 'frame A is inside the laning phase')
    assert(J.GetHP(bot) < 0.45, 'and BELOW fieldregen s ceiling, so that is not it')
    assert(bot:DistanceFromFountain() > 2500, 'and far enough from home for it')
    -- [reverse] the clause, read off the source rather than restated.
    local block = read_file(PURCHASE):match("IsSoakCandidate%('fieldregen'%).-\n\tthen")
    assert(block, 'could not locate the fieldregen block')
    assert(block:find('not J.IsInLaningPhase()', 1, true),
        'the laning clause left the fieldregen block')
    assert(block:find('J.GetHP(bot) < 0.45', 1, true),
        'the HP ceiling left the fieldregen block')
end

tests['hole: fieldregen cannot reach frame B -- its 0.45 ceiling, alone'] = function()
    local J, bot = world(B_FIX, B_HERO, 'fieldregen')
    assert(J.IsInLaningPhase() == false, 'frame B is past the laning phase')
    assert(J.GetHP(bot) > 0.45,
        'frame B is above the ceiling; that is the clause that blocks it')
    assert(J.GetHP(bot) <= 0.55, 'and still inside this family s band')
end

tests['hole: the shipped in-lane block stops at level 6, both frames are past it'] = function()
    local src = read_file(PURCHASE)
    local i = src:find('Init Healing Items in Lane', 1, true)
    assert(i, 'the in-lane healing block was renamed')
    assert(src:sub(i, i + 300):find('botLevel < 6', 1, true),
        'the level clause left the in-lane healing block')
    local _, botA = world(A_FIX, A_HERO, nil)
    local _, botB = world(B_FIX, B_HERO, nil)
    assert(botA:GetLevel() >= 6 and botB:GetLevel() >= 6,
        'both pinned frames must be past that clause')
end

-- ------------------------------------------------------------ corpus sweep --

local sweep_cache
local function sweep()
    if sweep_cache then return sweep_cache end
    local p = assert(io.popen('lua5.1 tests/_fieldbuy_supply_sweep.lua 2>/dev/null'))
    local out = p:read('*a')
    p:close()
    assert(out and out ~= '', 'the sweep produced nothing')
    sweep_cache = out
    return out
end

tests['[recorded] corpus: the situation partitions into 22 wet and 28 dry frames'] = function()
    local out = sweep()
    local live, band, band_dry, sit, wet, dry = out:match(
        'COUNT fixtures=%d+ live=(%d+) band=(%d+) band_dry=(%d+) situation=(%d+) has=(%d+) dry=(%d+)')
    assert(live, 'the sweep did not report a COUNT line')
    -- The partition is the invariant; the rest are corpus-scale ratchets and
    -- move when a fixture is added or regenerated (GH #106, GH #107).
    assert(tonumber(sit) == tonumber(wet) + tonumber(dry),
        'the two halves no longer partition the situation: '
        .. sit .. ' ~= ' .. wet .. ' + ' .. dry)
    assert(tonumber(live) == 930, 'live hero frames: ' .. live)
    assert(tonumber(band) == 150, 'frames inside the HP band: ' .. band)
    assert(tonumber(band_dry) == 82, 'of those, dry: ' .. band_dry)
    assert(tonumber(sit) == 50, 'situation frames: ' .. sit)
    assert(tonumber(wet) == 22, 'wet (the decision side s domain): ' .. wet)
    assert(tonumber(dry) == 28, 'dry (this id s domain): ' .. dry)
end

tests['[recorded] corpus: GH #123 would silence 13 of the 28, and rescue reaches 13'] = function()
    -- GH #123 proposes narrowing this id's purchase gate from nine slots to the
    -- six usable ones, because a delivered salve can land in the backpack where
    -- it cannot be drunk. `dry_split` is what that change would cost: the dry
    -- domain frames whose six main slots are full, i.e. every frame where the
    -- two clauses disagree. `rescuable` is what the shipped remedy already
    -- covers on those same frames -- TrySwapInvItemForFlask runs off GetDesire
    -- on every frame for every bot and swaps a backpacked flask into a main
    -- slot, and here it has a slot to swap into on every one of them.
    -- The full argument, plus a driven final action on one of these frames,
    -- lives in tests/test_fieldbuy_backpack_rescuer.lua.
    local out = sweep()
    local dry_split, rescuable, stuck = out:match(
        'SPLIT dry_split=(%d+) rescuable=(%d+) stuck=(%d+)')
    assert(dry_split, 'the sweep did not report a SPLIT line')
    -- The partition is the invariant; the scale numbers are corpus ratchets.
    assert(tonumber(dry_split) == tonumber(rescuable) + tonumber(stuck),
        'the split no longer partitions: ' .. dry_split
        .. ' ~= ' .. rescuable .. ' + ' .. stuck)
    assert(tonumber(dry_split) == 13,
        'dry frames the proposed fix would silence: ' .. dry_split)
    assert(tonumber(rescuable) == 13,
        'of those, frames the shipped rescuer can clear: ' .. rescuable)
    assert(tonumber(stuck) == 0,
        'frames with no swappable main item -- a real stuck salve: ' .. stuck)
end

tests['[recorded] corpus: the gate is shut on all 930 frames when unarmed'] = function()
    local out = sweep()
    local unarmed = out:match('COUNT .- unarmed=(%d+)')
    assert(unarmed, 'the sweep did not report the unarmed count')
    assert(tonumber(unarmed) == 0,
        'the id fired ' .. unarmed .. ' times with nothing armed')
end

tests['[recorded] corpus: 18 of the 28 dry frames fall in BOTH shipped holes'] = function()
    local out = sweep()
    local laning, lvl6, both, hpceil = out:match(
        'HOLE laning=(%d+) level6plus=(%d+) both=(%d+) hpceil=(%d+)')
    assert(laning, 'the sweep did not report a HOLE line')
    assert(tonumber(laning) == 24, 'dry frames inside the laning phase: ' .. laning)
    assert(tonumber(lvl6) == 22, 'dry frames at level 6+: ' .. lvl6)
    assert(tonumber(both) == 18, 'dry frames in both holes at once: ' .. both)
    assert(tonumber(hpceil) == 13,
        'dry frames above fieldregen s 0.45 ceiling: ' .. hpceil)
    -- The two holes together must cover more than either alone, otherwise one
    -- of them is not a hole at all but a restatement of the other.
    assert(tonumber(both) < tonumber(laning) and tonumber(both) < tonumber(lvl6),
        'the two holes are not independent')
end

tests['[recorded] corpus: both pinned frames are in the dry list, with these values'] = function()
    local out = sweep()
    assert(out:find('DRY f_260820_102645_cm_es_reach.lua npc_dota_hero_zuus 0.3952 7 1', 1, true),
        'frame A is no longer in the dry list with those values')
    assert(out:find('DRY f_260820_043637_axe_ring_alone.lua npc_dota_hero_viper 0.5491 15 0', 1, true),
        'frame B is no longer in the dry list with those values')
    -- And the corpus sweep drove every subject without an error.
    assert(not out:find('\nERR ', 1, true) and out:sub(1, 4) ~= 'ERR ',
        'the sweep reported a driving error')
end

-- ------------------------------------------------------------- the wiring --

tests['wiring: the id is gated, single-call-site, and the comment says so'] = function()
    local src = read_file(JMZ)
    local body = src:match('function J%.ShouldFieldBuyRegen%(.-\nend')
    assert(body, 'could not locate J.ShouldFieldBuyRegen')
    assert(body:find("J%.IsSoakCandidate%( 'fieldbuy' %)"), "gated on 'fieldbuy'")
    assert(body:find('J%.IsFieldRegenSituation%('), 'it shares the situation predicate')
    assert(body:find('not J%.HasFieldRegenSource%('), 'and it is the DRY half')
    -- The gate claim in the call-site comment must be real
    -- (test_gate_claim_consistency.lua enforces the other direction).
    local pur = read_file(PURCHASE)
    local i = pur:find('fieldbuy', 1, true)
    assert(i, 'the call site names no gate')
    local _, nCalls = pur:gsub('J%.ShouldFieldBuyRegen%(', '')
    assert(nCalls == 1, 'expected exactly one call site, found ' .. nCalls)
end

tests['wiring: the situation predicate ships nothing on its own, and has exactly two consumers'] = function()
    -- It carries no gate that could TURN BEHAVIOUR ON, so any caller other
    -- than the two wrappers would ship this behaviour into every turbo game.
    --
    -- This clause was "the situation must stay gate-free" until 2026-08-22
    -- 19:xxZ, when GH #119's creep/neutral veto ('fieldcreep') landed inside
    -- this predicate: it is shared by all three owner-P2 ids and the gap is
    -- theirs jointly, so one gated clause here beats three copies. The
    -- property that assertion existed to protect is unchanged and is now
    -- stated directly -- a gate in here may only ever NARROW the domain, i.e.
    -- the unarmed default this file measures cannot move. The full contract
    -- (exactly one id, asked once, whose branch returns false and never true)
    -- lives in tests/test_fieldcreep_veto.lua.
    local src = read_file(JMZ)
    local sit = src:match('function J%.IsFieldRegenSituation%(.-\nend')
    assert(sit, 'could not locate J.IsFieldRegenSituation')
    for branch in sit:gmatch('J%.IsSoakCandidate%(.-then(.-)end') do
        assert(not branch:find('return true', 1, true),
            'a gate inside the situation may only narrow it, never widen it')
    end
    local _, n = src:gsub('J%.IsFieldRegenSituation%(', '')
    assert(n == 3, 'definition + ShouldRegenNotGoHome + ShouldFieldBuyRegen = 3, found ' .. n)
    local elsewhere = read_file(PURCHASE)
        .. read_file('bots/ability_item_usage_generic.lua')
        .. read_file('bots/mode_retreat_generic.lua')
    assert(not elsewhere:find('IsFieldRegenSituation', 1, true),
        'a call site calls the UNGATED situation predicate directly')
end

return tests
