-- [itemtrip / GH #120, owner priority P2's family, above the health band]
--
-- The replay desk attributed 643 home TPs made above 55% HP across 283 turbo
-- games to every branch in bots/ that could explain one. 76 of them (11.8%,
-- 0.27/game) had no explanation: median HP 81.7%, 41 of the 76 with no enemy
-- inside 1600 for the entire trip, median round trip 40.1 seconds. The bearing
-- frame is lina `20260822_123136_slot3 t=434.6` -- full HP, nearest enemy
-- 4,212 units, courier visibly working -- who goes home anyway to combine an
-- orchid and pays 49 seconds, about 8% of a turbo game.
--
-- The pre-flight audit (tests/test_itemtrip_supply_gap.lua) established why no
-- branch explains it: BOT_MODE_ITEM is the ENGINE's mode here, because this
-- tree's item-mode file is disabled by its own filename. This file asserts the
-- repair at both ends -- the predicate J.IsWastefulItemTrip, and the FINAL
-- decision, which is the bid bots/mode_item_generic.lua actually installs.
--
-- The frames, and what each is for. Four of the seven live in ONE fixture --
-- the bearing frame's own world -- which is the strongest form these controls
-- come in: same map, same second, same everything except the quantity under
-- test.
--   A   123136_lina_shoptp_434 / lina        hp 1.000, ring 0, 11,240 from the
--                                            fountain -> WASTEFUL. #120's
--                                            bearing frame -- see the ⚠ below
--                                            on what is and is not settled
--                                            about its ATTRIBUTION.
--   N1  ...same fixture / skeleton_king      an enemy inside 1600 -> no. Going
--                                            home with company is a retreat.
--                                            ⚠ OVER-DETERMINED since the floor
--                                            moved: he is also 9,811 from the
--                                            fountain, inside the new 10000, so
--                                            he answers "no" for two reasons
--                                            and isolates neither. The 1600 pin
--                                            below (11,872 / 11,959, both past
--                                            the floor) is what still isolates
--                                            the ring; N1 is kept as a
--                                            regression, not as evidence.
--   N2  ...same fixture / zuus               3,422 from the fountain -> no.
--   N3  063722_lina_tp_home / lina           31.8% HP -> no, and this is owner
--                                            P2's OWN evidence frame: it
--                                            belongs to J.IsFieldRegenSituation
--                                            and must not belong to both.
--   N4  es_defend_1v3 / axe                  hit by a hero who is STILL in
--                                            reach -> no. Real geometry, ONE
--                                            synthesized quantity (the damage
--                                            bookkeeping): at the 10000 floor
--                                            NO corpus frame reaches this
--                                            clause at all. See the ⚠ above the
--                                            case.
--   N5  lion_meatgrinder / lion              damaged with nobody within 3000 ->
--                                            YES. The other side of N4, same
--                                            real-geometry/synthetic split, and
--                                            the global-ult shape the stayfield
--                                            family was reshaped for.
-- and three boundary pairs, which is where the constants are pinned:
--   1600  wk_l1trade_333: earthshaker at 1,597 (no) vs bristleback at 1,621
--         (yes) -- 24 units apart, same fixture.
--   10000 lion_drain_lethal/obsidian_destroyer at 9,988 (no) vs
--         od_eclipse_pair/viper at 10,023 (yes) -- 35 units apart. Replaces the
--         4,765/5,239 pair: the floor was corrected 5000 -> 10000 on
--         2026-08-23 because the first derivation halved a round trip whose
--         outbound leg is a TP, not a walk. The domain that error bought --
--         320 of 966 live frames, 33.1% -- is the census case's ratchet.
--   0.55  lina_tp_home/witch_doctor at 0.492 (no) vs wd_defend_alone/viper at
--         0.563 (yes).
--
-- Honest bounds, stated first rather than buried:
--   * Nothing here measures how often the built-in item mode WINS the auction.
--     That is #120's own 0.27/game, bought off batch replays; a fixture carries
--     no mode (the thirteenth world assertion: bot:GetActiveMode() is 0
--     everywhere). So this file proves the bid is suppressed WHEN item mode
--     asks -- not how often it asks.
--   * The `return nil` branch is asserted to BE nil, which is all a test can
--     do: whether the engine reads nil as "keep your built-in bid" is an
--     undischarged contract (docs/BOT_API_REFERENCE.md:52, zero users before
--     this one). bots/mode_item_generic.lua registers both outcomes and the
--     armed wave discharges it. A mock's auction is not evidence about the
--     engine's, so no test here pretends to settle it.
--   * The domain census below is over live hero frames, not over frames where
--     a hero was actually going home. It is a size, not a rate.
--
-- ⚠ OPEN, AND FOUND 11 MINUTES BEFORE THIS FILE LANDED -- READ BEFORE CITING
-- FRAME A AS "THE DEFECT". The replay desk's 2026-08-23T01:16Z report measures
-- that #120's `shop` label is excluded by a STEP boolean (X.IsInvFull) read at
-- 1Hz, and that 15.1% of the high-HP home-TP population sits in a band where
-- that read cannot decide, with 2.6% confirmed to flip on a finer regrid. On
-- run_121209 that took the residual from 15 to 12 (-20%), and every row it took
-- was a `shop` trip all along.
--
-- Frame A is one slot short of that band's own signature, from the other side:
-- this fixture -- a finer grid than the 1Hz sweep -- shows the bag FULL at the
-- instant the TP starts (modifier_teleporting, elapsed 0.0), while #120's 434.5
-- row still shows the ninth slot empty. So the live possibility is that frame A
-- is a `shop` trip (retreat mode's shop motive, 撤退:1) that 1Hz mis-excluded,
-- NOT a member of the 76-row residual -- and a shop trip does not route through
-- BOT_MODE_ITEM at all, which would make this lever unable to reach the very
-- trip it is pinned to.
--
-- What that does and does not change:
--   * It does NOT touch what this file asserts. Every case below is about what
--     the predicate and the bid answer ON THIS FRAME'S QUANTITIES, and those
--     are read off the fixture, not off #120's attribution.
--   * It does NOT dissolve the defect. The replay desk's own §5 keeps the
--     population: run_121209's remaining 12 rows are still near-full HP, still
--     unexplained, still 40s+ round trips.
--   * It DOES make the reason this file gives for omitting an inventory clause
--     PROVISIONAL rather than settled -- see that case's own comment.
--   * Baton (filed with the round's report): the replay desk re-attributes
--     frame A at 0.1s. If it settles as `shop`, this file needs a replacement
--     bearing frame drawn from the residual AFTER the -20% correction, and the
--     inventory clause has to be re-argued from scratch rather than inherited.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local JMZ = 'bots/FunLib/jmz_func.lua'
local MODE = 'bots/mode_item_generic.lua'
local GATE = 'itemtrip'

local A_FIX = 'tests/fixtures/f_260822_123136_lina_shoptp_434.lua'
local HOME_FIX = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local WD_FIX = 'tests/fixtures/f_260820_043524_wd_defend_alone.lua'
local RING_FIX = 'tests/fixtures/f_260820_181711_wk_l1trade_333.lua'
local NEAR_FIX = 'tests/fixtures/f_045650_lion_meatgrinder.lua'
-- The fountain-floor boundary pair, re-cut when the floor moved 5000 -> 10000
-- (2026-08-23). 35 units apart across the new literal, which is tighter than
-- the pair it replaces (4,765 / 5,239) and pins the constant harder.
local UNDER_FIX = 'tests/fixtures/f_260820_162821_lion_drain_lethal.lua'
local OVER_FIX = 'tests/fixtures/f_260819_222559_od_eclipse_pair.lua'
-- The attributed-damage pair. At the 10000 floor NO frame in the corpus
-- reaches that clause at all (see the ⚠ in the census case), so both sides are
-- real geometry with ONE synthesized quantity -- the damage bookkeeping.
local ATTR_FIX = 'tests/fixtures/f_050713_es_defend_1v3.lua'

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

--- Load the item-mode file into a fixture world and report what it installed.
--- This is the FINAL decision, not the predicate: the engine's only question
--- of a mode script is whether GetDesire exists and what it answers.
local function item_bid(fix, hero, armed)
    local J, bot = world(fix, hero, armed)
    GetDesire = nil -- luacheck: ignore
    local ok, err = pcall(dofile, MODE)
    assert(ok, MODE .. ' failed to load: ' .. tostring(err))
    local installed = type(GetDesire) == 'function'
    local value, called = nil, false
    if installed then
        local ok2, d = pcall(GetDesire)
        assert(ok2, 'GetDesire crashed: ' .. tostring(d))
        value, called = d, true
    end
    GetDesire = nil -- luacheck: ignore
    return installed, value, called, J, bot
end

-- ------------------------------------------------------------------ frame A --

tests['frame A: the bearing frame is wasteful, and every clause is shown'] = function()
    local J, bot = world(A_FIX, 'npc_dota_hero_lina', nil)
    assert(J.IsWastefulItemTrip(bot) == true,
        'the predicate no longer holds on #120\'s bearing frame')
    -- Shown rather than asserted in the aggregate, so a later failure says
    -- WHICH quantity moved.
    assert(J.GetHP(bot) == 1.0, 'she is at full health')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'the 1600 ring is empty')
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false, 'nobody has hit her')
    local d = J.GetDistanceFromAllyFountain(bot)
    assert(d > 11000 and d < 11500,
        'distance from her own fountain moved: ' .. string.format('%.0f', d))
end

tests['frame A: the bag is FULL -- the inventory clause that was NOT written'] = function()
    -- The finding, pinned so nobody re-adds the obvious clause. The draft of
    -- this lever carried `Item.GetEmptyInventoryAmount( bot ) > 0` on the
    -- reasoning that a full bag is a legitimate fetch trip. On THIS frame the
    -- bag is full -- the courier delivered the claymore into the ninth slot
    -- shortly before the snapshot, which is why #120's own 434.5 row still
    -- shows the slot empty -- so that clause would have made the lever inert on
    -- its own bearing frame. That is the Luna-chase failure mode
    -- (tests/test_replay_071423_luna_chase.lua).
    --
    -- ⚠ PROVISIONAL as of 2026-08-23T01:16Z, and the counter-evidence is named
    -- rather than waited out: the replay desk measured that the SAME full bag
    -- is how #120's `shop` label is decided, and that reading it at 1Hz is
    -- undecidable for 15.1% of the population. If frame A settles as a `shop`
    -- trip, then "the clause would be inert here" stops being an argument
    -- against the clause and becomes an argument that this frame is out of the
    -- lever's reach entirely -- and the clause should go in, since a full bag
    -- means the courier CANNOT deliver and the trip has a reason. The number
    -- below is what makes that flip cheap to evaluate either way: 14 of the 310
    -- wasteful frames, 4.5% of the domain (asserted in the census case).
    -- The clause is left out TODAY because flipping it on a report eleven
    -- minutes old, without re-attributing the frame first, would be trading a
    -- measured decision for a fresh guess.
    local _, bot = world(A_FIX, 'npc_dota_hero_lina', nil)
    local empty = 0
    for i = 0, 8 do
        if bot:GetItemInSlot(i) == nil then empty = empty + 1 end
    end
    assert(empty == 0,
        'the bearing frame no longer has a full bag (' .. empty .. ' free) -- the '
        .. 'argument for omitting the inventory clause rested on this')
end

tests['frame A: the FINAL decision -- armed, the item-mode bid is NONE'] = function()
    local installed, value, called = item_bid(A_FIX, 'npc_dota_hero_lina', GATE)
    assert(installed, 'armed: the item-mode file installs no GetDesire')
    assert(called and value == BOT_MODE_DESIRE_NONE,
        'armed: the bid on the bearing frame is ' .. tostring(value)
        .. ', expected BOT_MODE_DESIRE_NONE')
end

tests['frame A: unarmed, the file installs NOTHING -- the engine keeps its bid'] = function()
    -- The whole safety argument. Unarmed, there is no script GetDesire for the
    -- engine to call, so an unarmed game is byte-for-byte the game we ship.
    local installed = item_bid(A_FIX, 'npc_dota_hero_lina', nil)
    assert(installed == false,
        'unarmed: the item-mode file installed a GetDesire -- the load-time gate '
        .. 'is broken and this behaviour is SHIPPING')
end

tests['frame A: another id armed is still not this id'] = function()
    -- Gate isolation: arming a sibling in the same wave must not switch this on,
    -- or a per-id A/B cannot tell them apart (GH #29).
    local installed = item_bid(A_FIX, 'npc_dota_hero_lina', 'stayfield')
    assert(installed == false,
        "arming 'stayfield' installed the itemtrip bid")
end

-- ------------------------------------------------------- negative controls --

tests['N1: an enemy inside the ring -- going home is a retreat, not a trip'] = function()
    local J, bot = world(A_FIX, 'npc_dota_hero_skeleton_king', nil)
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 1,
        'the ring is no longer occupied on this frame')
    assert(J.GetHP(bot) > 0.55 and J.GetDistanceFromAllyFountain(bot) > 5000,
        'this control only isolates the ring if the other clauses pass')
    assert(J.IsWastefulItemTrip(bot) == false, 'company in the ring must veto')
    local installed, value = item_bid(A_FIX, 'npc_dota_hero_skeleton_king', GATE)
    assert(installed and value == nil,
        'armed and not wasteful: the bid must be nil (deferred), got ' .. tostring(value))
end

tests['N2: close to home the walk is not the cost #120 measured'] = function()
    local J, bot = world(A_FIX, 'npc_dota_hero_zuus', nil)
    local d = J.GetDistanceFromAllyFountain(bot)
    assert(d > 3000 and d < 5000, 'zuus moved off the near-home band: ' .. string.format('%.0f', d))
    assert(J.GetHP(bot) == 1.0 and #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'this control only isolates distance if the other clauses pass')
    assert(J.IsWastefulItemTrip(bot) == false, 'a short trip is not this lever\'s business')
end

tests['N3: owner P2\'s own frame belongs to the OTHER half of the family'] = function()
    -- The partition, asserted on the frame owner cited: at 31.8% HP this is
    -- J.IsFieldRegenSituation's, and if both ever claimed one frame the "no gap,
    -- no overlap across the health axis" argument in both head comments would be
    -- false.
    local J, bot = world(HOME_FIX, 'npc_dota_hero_lina', nil)
    assert(J.GetHP(bot) < 0.55, 'the pinned frame is no longer in the hurt band')
    assert(J.IsFieldRegenSituation(bot) == true,
        'the field-regen half no longer claims owner P2\'s frame')
    assert(J.IsWastefulItemTrip(bot) == false,
        'itemtrip claims a frame the field-regen half already owns -- the two '
        .. 'halves must partition the health axis, not overlap on it')
end

-- ⚠ N4 AND N5 WERE RE-CUT WHEN THE FOUNTAIN FLOOR MOVED 5000 -> 10000, and the
-- honest statement about what they now are comes first.
--
-- Their previous frames were 043524_wd_defend_alone/witch_doctor (6,094 from
-- home) and 063722_lina_tp_home/drow_ranger (9,462). Both sit INSIDE the new
-- floor, so the old N4 would still have passed -- for the distance reason, not
-- the attribution one, i.e. a false green -- and the old N5, which asserts the
-- predicate holds, would simply have gone red.
--
-- The replacement is not a better fixture, because there is no better fixture:
-- a corpus sweep over all 104 fixtures / 966 live hero frames finds ZERO frames
-- with hp >= 0.55, an empty 1600 ring, >= 10000 from the fountain AND recent
-- hero damage. At this floor the attributed-damage clause is unreachable on the
-- whole corpus (the census reads WHY dmg = 0), which is a coverage GAP, not a
-- reason to move the floor to wherever a test frame happens to sit.
--
-- So both cases keep REAL geometry -- a real frame, real hero positions, the
-- real 3000-ring occupancy that decides the clause -- and synthesize exactly
-- one quantity: the damage bookkeeping the fixture does not record. That split
-- is stated per case, and the geometry is asserted from the frame so a re-cut
-- fixture fails loudly instead of quietly testing nothing.
--
-- Registered as a fixture request rather than left implicit: a frame that is
-- healthy, ring-empty, >= 10000 from home and recently damaged (one with the
-- damager inside 3000, one with them outside) would retire both synthetics.

--- Real frame, synthetic damage bookkeeping. `by` is the enemy the damage is
--- attributed to, or nil for damage nobody nearby dealt.
local function with_damage(J, bot, by)
    bot.WasRecentlyDamagedByAnyHero = function() return true end
    bot.WasRecentlyDamagedByHero = function(_, hEnemy) return hEnemy == by end
    return J, bot
end

tests['N4: recent hero damage from someone STILL in reach vetoes'] = function()
    local J, bot = world(ATTR_FIX, 'npc_dota_hero_axe', nil)
    -- Real, and each one asserted: without these the case would pass on a
    -- frame where some other clause is doing the work.
    assert(J.GetHP(bot) > 0.9, 'he is healthy')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) == 0,
        'and the 1600 ring is empty, so only the attribution can speak here')
    assert(J.GetDistanceFromAllyFountain(bot) > 10000,
        'and he is past the fountain floor, so that clause cannot answer either')
    local ring3000 = J.GetNearbyHeroes(bot, 3000, true, BOT_MODE_NONE)
    assert(#ring3000 == 1,
        'the attribution ring no longer holds exactly one enemy -- this frame '
        .. 'was chosen because it does')
    assert(J.IsWastefulItemTrip(bot) == true,
        'before the synthetic damage this frame must be IN the domain, or the '
        .. 'veto below proves nothing')
    -- Synthetic: the one quantity a fixture does not carry.
    with_damage(J, bot, ring3000[1])
    assert(J.IsWastefulItemTrip(bot) == false,
        'the attributed-damage clause must veto: the hero who hit him is inside 3000')
end

tests['N5: damage nobody nearby dealt is NOT someone chasing me'] = function()
    -- The other side of N4, and the shape the stayfield family was reshaped
    -- for: a global ult reads as "a hero damaged me" with nobody anywhere near.
    local J, bot = world(NEAR_FIX, 'npc_dota_hero_lion', nil)
    assert(#J.GetNearbyHeroes(bot, 3000, true, BOT_MODE_NONE) == 0,
        'nobody is within the attribution radius -- that is why this frame')
    assert(J.GetDistanceFromAllyFountain(bot) > 10000, 'and he is past the floor')
    assert(J.IsWastefulItemTrip(bot) == true, 'undamaged, he is in the domain')
    -- Synthetic: damaged, but by nobody the attribution loop can find.
    with_damage(J, bot, nil)
    assert(J.IsWastefulItemTrip(bot) == true,
        'unattributed damage must not veto, or the lever dies to every global ult')
end

-- --------------------------------------------------------- boundary pinning --

-- ⚠ A LOADED FIXTURE WORLD IS A SET OF GLOBALS, so two of them cannot coexist:
-- rf.load installs GetTeam/GetUnitList/... over the previous world's, and a
-- helper called on the FIRST world afterwards silently answers in the second
-- one's frame of reference. This cost a real failure while writing this file --
-- the near-distance control below read 15,316 instead of 4,765, which is axe's
-- distance to the OTHER team's fountain, because the far control had been
-- loaded on the line above. Every boundary pair therefore reads one world to
-- completion BEFORE loading the next; it is not a style preference.
local function verdict(fix, hero)
    local J, bot = world(fix, hero, nil)
    return {
        wasteful = J.IsWastefulItemTrip(bot),
        hp = J.GetHP(bot),
        ring = #J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE),
        home = J.GetDistanceFromAllyFountain(bot),
    }
end

tests['pin 1600: 1,597 vetoes and 1,621 does not, in one fixture'] = function()
    local a = verdict(RING_FIX, 'npc_dota_hero_earthshaker')
    local b = verdict(RING_FIX, 'npc_dota_hero_bristleback')
    assert(a.wasteful == false, 'nearest enemy 1,597: inside the ring')
    assert(b.wasteful == true, 'nearest enemy 1,621: outside the ring')
    -- Both pass the other clauses, so the pair isolates the radius: move 1600
    -- past 1621 and the second fails; move it below 1597 and the first fails.
    assert(a.ring == 1, 'the earthshaker control no longer has company in the ring')
    assert(a.hp > 0.55 and a.home > 10000,
        'the earthshaker control stopped isolating the ring')
    assert(b.home > 10000,
        'the bristleback control fell inside the fountain floor -- it would '
        .. 'then answer "yes" for a reason this pair does not control')
    assert(b.ring == 0, 'the bristleback control gained company in the ring')
end

tests['pin 10000: 9,988 vetoes and 10,023 does not -- 35 units apart'] = function()
    local a = verdict(UNDER_FIX, 'npc_dota_hero_obsidian_destroyer')
    local b = verdict(OVER_FIX, 'npc_dota_hero_viper')
    assert(a.home > 9900 and a.home < 10000, 'the near control moved: ' .. string.format('%.0f', a.home))
    assert(b.home > 10000 and b.home < 10100, 'the far control moved: ' .. string.format('%.0f', b.home))
    assert(a.wasteful == false, '9,988 from home: 12 units below the floor')
    assert(b.wasteful == true, '10,023 from home: 23 units above it')
    -- Both pass every other clause, so the pair isolates the literal: this is
    -- the case that goes red if somebody restores 5000 without re-deriving it.
    assert(a.hp > 0.55 and a.ring == 0 and b.hp > 0.55 and b.ring == 0,
        'a control picked up another reason to answer the way it does')
end

tests['the floor is 10000, and it is the CORRECTED conversion'] = function()
    -- WHY THIS CASE EXISTS. The 5000 that shipped came from #120's median
    -- round trip of 40.1s -> "~12,000 units of walking, i.e. ~6,000 one way"
    -- -> floored to 5000. The halving is the error: #120's population is 643
    -- home TPs, so the outbound leg is the TP and only the return leg is
    -- walked. The walked ~12,000 IS the one-way distance from home. A comment
    -- can drift from its literal, so the literal is read off source here and
    -- the arithmetic is asserted rather than described.
    local src = read_file(JMZ)
    local body = src:match('\nfunction J%.IsWastefulItemTrip%( bot %)(.-)\nend\n')
    assert(body, 'J.IsWastefulItemTrip is gone or is no longer a top-level function')
    local floor = tonumber(body:match('J%.GetDistanceFromAllyFountain%( bot %) < ([%d%.]+)'))
    assert(floor, 'the fountain clause no longer has a literal bound')
    -- 40.1s at ~300 movement speed, one way, with the same ~0.83 conservative
    -- discount the first derivation applied to its own (wrong) number.
    local derived = 40.1 * 300 * 0.83
    assert(floor > derived * 0.95 and floor < derived * 1.05,
        'the fountain floor (' .. floor .. ') is no longer the corrected '
        .. 'conversion of #120\'s 40.1s round trip (' .. string.format('%.0f', derived)
        .. ') -- if the floor moved on purpose, move this derivation with it')
    -- And the cap on the other side: above the bearing frame the lever is
    -- inert on the frame that motivated it, which is the Luna-chase failure
    -- mode. Read from the frame, not restated.
    local a = verdict(A_FIX, 'npc_dota_hero_lina')
    assert(floor < a.home,
        'the floor (' .. floor .. ') is now past #120\'s bearing frame ('
        .. string.format('%.0f', a.home) .. ') -- the lever cannot act on its '
        .. 'own evidence any more')
    assert(a.home - floor > 1000,
        'less than 1,000 units of margin between the floor and the bearing '
        .. 'frame -- one re-cut of that fixture and the lever goes inert')
end

tests['pin 0.55: 0.492 vetoes and 0.563 does not, and it is ONE number'] = function()
    local a = verdict(HOME_FIX, 'npc_dota_hero_witch_doctor')
    local b = verdict(WD_FIX, 'npc_dota_hero_viper')
    assert(a.hp > 0.45 and a.hp < 0.55, 'the hurt control moved: ' .. tostring(a.hp))
    assert(b.hp > 0.55 and b.hp < 0.65, 'the healthy control moved: ' .. tostring(b.hp))
    assert(a.wasteful == false, '49.2% health: the hurt band')
    assert(b.wasteful == true, '56.3% health: healthy')
    -- And the SAME number is the field-regen half's ceiling. The "no gap, no
    -- overlap" claim in both head comments is only true while these two literals
    -- agree, so it is read off source rather than trusted.
    local src = read_file(JMZ)
    local regen = src:match('\nfunction J%.IsFieldRegenSituation%( bot %)(.-)\nend\n')
    local trip = src:match('\nfunction J%.IsWastefulItemTrip%( bot %)(.-)\nend\n')
    assert(regen and trip, 'one of the two halves is gone or was renamed')
    local ceiling = regen:match('nHP > ([%d%.]+) then return false')
    local floor = trip:match('J%.GetHP%( bot %) < ([%d%.]+) then return false')
    assert(ceiling and floor, 'the health clauses no longer have literal bounds')
    assert(ceiling == floor,
        'the two halves of owner P2\'s family drifted apart: field-regen stops at '
        .. tostring(ceiling) .. ' but itemtrip starts at ' .. tostring(floor)
        .. ' -- one of the health bands is now unowned (or claimed twice)')
end

-- ------------------------------------------------------------------ census --

tests['[census] the domain, and the inventory clause that was not written'] = function()
    local p = assert(io.popen('lua5.1 tests/_itemtrip_sweep.lua 2>&1'))
    local manifest = p:read('*a')
    p:close()
    assert(manifest:find('\nDONE\n') or manifest:find('^DONE\n'),
        'the corpus sweep did not finish:\n' .. manifest)
    local function num(pat)
        local v = manifest:match(pat)
        assert(v, 'the sweep no longer reports ' .. pat .. ':\n' .. manifest)
        return tonumber(v)
    end
    local live = num('C live (%d+)')
    local wasteful = num('C wasteful (%d+)')
    -- Floors, not equalities: adding a fixture must make this census stronger,
    -- not red (GH #127 -- seven files went red at once the last time a corpus
    -- size was pinned as an equation).
    assert(num('C fixtures (%d+)') >= 101, 'the corpus shrank')
    assert(live >= 940, 'live hero frames dropped below the measured floor')
    -- ⚠ THIS BAND IS A RATCHET NOW, AND THE OLD ONE IS THE FINDING.
    -- It used to read `wasteful >= 250 and <= live * 0.45`, i.e. it certified
    -- a domain of 320 of 966 live frames -- 33.1%, a third of every frame the
    -- corpus has -- as normal. Meanwhile the lever was requested, armed and
    -- priced against #120's 0.038 UNEXPLAINED TRIPS PER GAME. Those are not
    -- the same measurement and were never comparable: this predicate selects
    -- FRAMES, a bot sits in-domain for hundreds of consecutive frames without
    -- making any trip, and the bid is paid per frame. The 33.1% is what the
    -- batch actually bought at gpm -26.44 (director 14:58Z), which is why the
    -- lever came back. Correcting the fountain floor 5000 -> 10000 took it to
    -- 135 of 966 (14.0%). The upper bound is therefore the ratchet: it may
    -- come down, never back up, and re-arming this id means re-reading this
    -- number first.
    assert(wasteful <= live * 0.16,
        'the domain grew back past the ratchet: ' .. wasteful .. ' of ' .. live
        .. ' (' .. string.format('%.1f', 100 * wasteful / live) .. '%) -- it was '
        .. 'cut to 14.0% precisely because a 33.1% frame domain is what the '
        .. 'batch priced at gpm -26.44')
    assert(wasteful >= 60,
        'the domain collapsed to ' .. wasteful .. ' of ' .. live .. ' -- a lever '
        .. 'that cannot reach anything is not a narrower lever, it is a dead one')
    -- The why-decomposition has to add up to the population, or it is measuring
    -- a different function than the one that shipped.
    local sum = num('WHY yes (%d+)') + num('WHY hp (%d+)') + num('WHY ring (%d+)')
        + num('WHY dist (%d+)') + num('WHY dmg (%d+)')
    assert(sum == live, 'the clause decomposition covers ' .. sum .. ' of ' .. live
        .. ' live frames -- some frame refuses for a reason not in the list')
    assert(num('WHY yes (%d+)') == wasteful, 'the decomposition disagrees with the predicate')
    -- ⚠ THE COVERAGE THE FLOOR MOVE COST, asserted rather than mentioned.
    -- At the 5000 floor the attributed-damage clause decided exactly ONE frame
    -- in the corpus. At 10000 it decides NONE: that frame refuses at the
    -- fountain clause first, and a sweep over all 966 live frames finds zero
    -- with hp >= 0.55, an empty 1600 ring, >= 10000 from home AND recent hero
    -- damage. So the clause is now reachable only through N4/N5, which are
    -- real geometry plus one synthesized quantity. Asserted as an EQUALITY on
    -- purpose: if a future fixture makes this 1 again, that is a real frame
    -- for a clause that currently has none, and this case should go red so
    -- somebody promotes it into N4/N5 and drops the synthetic.
    assert(num('WHY dmg (%d+)') == 0,
        'a corpus frame reaches the attribution clause again -- good news, but '
        .. 'N4/N5 are still running on synthesized damage; re-cut them on the '
        .. 'real frame and delete with_damage()')
    -- And the measured cost of the clause that was NOT written: a "bag not
    -- full" clause would remove this many wasteful frames -- 14 of 310 when
    -- measured -- one of which is the bearing frame itself.
    local bag_full = num('BAG full (%d+)')
    assert(bag_full >= 1 and bag_full <= wasteful * 0.15,
        'full-bag frames inside the domain moved to ' .. bag_full .. ' of ' .. wasteful
        .. ' -- the argument for omitting the inventory clause was that this is small '
        .. 'AND contains the bearing frame; re-read it before trusting either half')
end

return tests
