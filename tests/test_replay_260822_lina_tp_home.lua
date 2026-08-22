-- [stayfield / owner priority P2] Low HP + nobody anywhere near + a heal in
-- the bag -> the bot TPs home anyway and loses 20 seconds of a 20 minute game.
--
-- The frame (replay desk 2026-08-22T08:50Z, GH #111 §2.4, verified again here
-- straight off the .dem): 20260822_063722_slot1, seed 888, dire armed, Lina at
-- t=349.1 presses a TP that lands 33 units from her own fountain. At the
-- decision instant she is at 346/1088 = 31.8% HP, the NEAREST enemy hero is
-- 6,596 units away, the nearest ally 6,463, and slot 0 holds a faerie_fire.
-- She leaves the fountain again at 369.4 -- 20.3 seconds -- and at 365.4 the
-- nearest enemy is still 8,968 units away, i.e. nothing was happening to her
-- either before or after.
--
-- This replaces the frame owner priority P2 / GH #110 originally pinned
-- (063559 Slardar t=636): the replay desk showed that TP landed 12,646 units
-- from its own fountain -- a FORWARD tp, not a trip home. That frame is
-- carried here instead as the negative control it actually is.
--
-- Two independent shipped facts make this frame unreachable for the existing
-- regen veto J.ShouldStayAndRegen, and the new guard answers both:
--   (1) the veto is wired only into the tpscroll '撤退:1' branch (HP < 0.19);
--       at 31.8% the branch that can fire is '撤退:3', which has no regen veto;
--   (2) the veto's danger read is WasRecentlyDamagedByAnyHero(3.0), and 2.6s
--       before the decision a Zeus 7,533 units away landed Thundergod's Wrath
--       (global ult, 204 damage) -- so "a hero damaged me" reads TRUE with no
--       hero anywhere near. J.ShouldRegenNotTpHome ATTRIBUTES that damage:
--       recent hero damage only vetoes if the dealer is still within 3000.
--
-- Test surface:
--   * J.ShouldRegenNotTpHome on both real frames, gate off/on, each clause
--     mutated so the deciding clause on each frame is named, not assumed;
--   * the branch attribution on the Lina frame (which of the four home-TP
--     branches could have produced this TP), asserted from the frame;
--   * source tripwire that the guard sits on the '撤退:3' HIGH return;
--   * the two world assumptions this file runs under, written down as
--     assertions rather than left implicit.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local SLARDAR = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua'

local tests = {}

--- Load a fixture with (turbo, gate) freely armed via the returned J.
local function load_fx(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    J.IsModeTurbo = function() return opts.turbo == true end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == 'stayfield'
    end
    return J, bot, heroes, fx
end

local function hp_pct(u) return u:GetHealth() / u:GetMaxHealth() end

local function dist(a, b)
    local la, lb = a:GetLocation(), b:GetLocation()
    return math.sqrt((la.x - lb.x) ^ 2 + (la.y - lb.y) ^ 2)
end

-- ---------------------------------------------------------------------------
-- The frame itself, before any decision is asked of it.

tests['frame A: the world at the decision instant is the one GH #111 describes'] = function()
    local _, bot, heroes = load_fx(LINA, { turbo = true, armed = true })
    assert(bot:GetUnitName() == 'npc_dota_hero_lina', 'subject is Lina')
    assert(math.abs(hp_pct(bot) - 0.318) < 0.005,
        'Lina is at 31.8% HP (346/1088), saw ' .. string.format('%.3f', hp_pct(bot)))
    assert(bot:GetLevel() == 9, 'level 9 -- it matters, 撤退:3 needs >= 9')
    -- Nearest enemy hero on the whole map, computed from the frame rather than
    -- from any vision helper.
    local nNearest = nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            local d = dist(bot, h)
            if nNearest == nil or d < nNearest then nNearest = d end
        end
    end
    assert(nNearest > 6000,
        'the nearest living enemy is 6,596 away, saw ' .. math.floor(nNearest or -1))
    assert(bot:DistanceFromFountain() > 9000,
        'and she is ~10,000 from her own fountain -- the trip she is about to take')
end

tests['frame A: the "I am under attack" read is a GLOBAL ult, 7.5k away'] = function()
    local _, bot, heroes = load_fx(LINA, { turbo = true, armed = true })
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == true,
        'the shipped danger read answers TRUE here -- that is the whole problem')
    local zuus = heroes['npc_dota_hero_zuus']
    assert(zuus ~= nil and bot:WasRecentlyDamagedByHero(zuus, 3.0) == true,
        'and Zeus is the hero it is answering about')
    assert(dist(bot, zuus) > 7000,
        'who is 7,533 units away: Thundergod\'s Wrath, not a chase')
    -- Nobody else touched her: the attribution has exactly one hero to check.
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h ~= zuus then
            assert(bot:WasRecentlyDamagedByHero(h, 3.0) == false,
                'no other enemy damaged her inside the window')
        end
    end
end

-- ---------------------------------------------------------------------------
-- The guard, gated.

tests['frame A, gate OFF: the guard is inert'] = function()
    local J, bot = load_fx(LINA, { turbo = true, armed = false })
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'unarmed -> shipped behaviour, the TP home still happens')
end

tests['frame A, non-turbo: the guard is inert'] = function()
    local J, bot = load_fx(LINA, { turbo = false, armed = true })
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'turbo-only gate: normal-mode games must see shipped behaviour')
end

tests['frame A, gate ON: hurt, alone, heal in the bag -> STAY'] = function()
    local J, bot = load_fx(LINA, { turbo = true, armed = true })
    assert(J.ShouldRegenNotTpHome(bot) == true,
        '31.8% HP, empty 1600 ring, faerie_fire in slot 0: drink it, do not '
        .. 'spend 20 seconds in the fountain')
end

tests['frame A: the attribution clause is what lets it through'] = function()
    local J, bot, heroes = load_fx(LINA, { turbo = true, armed = true })
    -- Walk the SAME Zeus hit into the 3000 ring: same damage, same window,
    -- only the dealer's position changes. The guard must then stand down --
    -- an enemy who just hit me and is still on top of me is a real retreat.
    local zuus = heroes['npc_dota_hero_zuus']
    local vBot = bot:GetLocation()
    rawget(zuus, '__spec').GetLocation = Vector(vBot.x + 1800, vBot.y, vBot.z or 0)
    rawset(zuus, 'GetLocation', nil)
    assert(dist(bot, zuus) < 3000 and dist(bot, zuus) > 1600,
        'sanity: Zeus now sits inside the attribution ring but outside the 1600 one')
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'the damage is now attributable to a hero within reach -> let the TP through')
end

tests['frame A: the empty 1600 ring is load-bearing on its own'] = function()
    local J, bot, heroes = load_fx(LINA, { turbo = true, armed = true })
    -- Bring an enemy who has NOT damaged her into the ring the guarded branch
    -- itself measures. The attribution clause stays quiet (spirit_breaker
    -- never touched her), so only the ring can be doing the work.
    local sb = heroes['npc_dota_hero_spirit_breaker']
    assert(bot:WasRecentlyDamagedByHero(sb, 3.0) == false,
        'sanity: spirit_breaker is not in her damage history')
    local vBot = bot:GetLocation()
    rawget(sb, '__spec').GetLocation = Vector(vBot.x + 1200, vBot.y, vBot.z or 0)
    rawset(sb, 'GetLocation', nil)
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'an enemy inside 1600 -- the branch tolerates one, this guard does not')
end

tests['frame A: no heal in the bag -> the guard does not fire'] = function()
    local J, bot = load_fx(LINA, { turbo = true, armed = true })
    assert(J.HasFieldRegenSource(bot) == true, 'sanity: faerie_fire is in slot 0')
    -- Take the faerie_fire away and leave everything else exactly as it was.
    -- Standing at 31.8% with nothing to drink is idling, not regening.
    local slots = {}
    for i = 0, 16 do slots[i] = bot:GetItemInSlot(i) end
    rawget(bot, '__spec').GetItemInSlot = function(_, i)
        local it = slots[i]
        if it ~= nil and it:GetName() == 'item_faerie_fire' then return nil end
        return it
    end
    rawset(bot, 'GetItemInSlot', nil)
    assert(J.HasFieldRegenSource(bot) == false, 'sanity: the bag is now heal-less')
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'nothing to regen with -> the shipped trip home stands')
end

tests['frame A: the HP band has both edges'] = function()
    local J, bot = load_fx(LINA, { turbo = true, armed = true })
    local nMax = bot:GetMaxHealth()
    -- J.GetHP reads OriginalGetHealth for an own-team unit (jmz_func:3720), so
    -- a mutation that only moves GetHealth would leave the helper reading the
    -- real frame and this test would pass without measuring anything.
    local function set_hp(f)
        local spec = rawget(bot, '__spec')
        spec.GetHealth = math.floor(nMax * f + 0.5)
        spec.OriginalGetHealth = spec.GetHealth
        rawset(bot, 'GetHealth', nil)
        rawset(bot, 'OriginalGetHealth', nil)
    end
    set_hp(0.60)
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'above the band the bot is not hurt enough for this question')
    set_hp(0.10)
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'below the floor a genuine escape/heal retreat stands')
    set_hp(0.318)
    assert(J.ShouldRegenNotTpHome(bot) == true, 'and back inside the band it fires again')
end

-- ---------------------------------------------------------------------------
-- Which home-TP branch could have produced this TP. The consider function
-- itself cannot be driven on a fixture (see the world-assumption block at the
-- bottom), so the attribution is done by eliminating the other three branches
-- on the frame's own numbers.

tests['frame A: 撤退:1, 撤退:2 and 回复状态 are all excluded by HP'] = function()
    local _, bot = load_fx(LINA, { turbo = true, armed = true })
    local nHP = hp_pct(bot)
    local nMP = bot:GetMana() / bot:GetMaxMana()
    assert(nHP >= 0.19, '撤退:1 needs HP < 0.19')
    -- 撤退:2's threshold is 0.15 + 0.24 * (enemies within 1600), and the ring
    -- is empty on this frame, so the threshold is its floor.
    assert(nHP >= 0.15, '撤退:2 needs HP < 0.15 with an empty 1600 ring')
    assert(nHP >= 0.20 and (nHP + nMP) >= 0.30,
        '回复状态 needs HP < 0.20 or HP+MP < 0.30; she is at '
        .. string.format('%.2f + %.2f', nHP, nMP))
end

tests['frame A: every 撤退:3 clause the frame can answer holds'] = function()
    local J, bot, heroes = load_fx(LINA, { turbo = true, armed = true })
    assert(hp_pct(bot) < 0.34, 'HP < 0.34')
    assert(bot:GetLevel() >= 9, 'level >= 9')
    assert(#J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE) <= 1,
        'nEnemyCount = X.GetNumHeroWithinRange(1600) <= 1')
    assert(J.GetAllyCount(bot, 1600) <= 2, 'nAllyCount = J.GetAllyCount(bot,1600) <= 2')
    assert(J.IsItemAvailable('item_flask') == nil, 'itemFlask == nil -- no salve carried')
    -- nMinTPDistance is 5500 and this branch reads it minus 600.
    assert(bot:DistanceFromFountain() > 5500 - 600, 'far enough from the fountain')
    -- And the one clause the frame cannot answer is named rather than assumed:
    -- X.CanJuke() and bot:GetAttackTarget() are bot-VM state, not entity state,
    -- so they are absent from every fixture (same family as GH #89).
    assert(bot:GetAttackTarget() == nil,
        'GetAttackTarget answers nil on every fixture -- the mock default, not a '
        .. 'measurement of this frame')
    -- Ground truth from the replay closes the loop the fixture cannot: the TP
    -- was cast, and it landed 33 units from her own fountain.
    local zuus = heroes['npc_dota_hero_zuus']
    assert(zuus ~= nil, 'the frame is the one the ground truth belongs to')
end

tests['frame A ground truth: nothing was chasing her, before or after'] = function()
    local _, _, _, fx = load_fx(LINA, { turbo = true, armed = true })
    assert(next(fx.observed.burst) == nil,
        'no enemy hero dealt her any damage in the 5s after the decision')
    assert(fx.observed.died_after ~= nil and fx.observed.died_after > 100,
        'and she lived for another 110 seconds -- the trip home bought nothing '
        .. 'she needed, saw ' .. tostring(fx.observed.died_after))
end

-- ---------------------------------------------------------------------------
-- Frame B (negative control): 20260822_063559_slot1, seed 896, dire armed,
-- Slardar t=635.9 -- the frame P2/#110 originally pinned. He is at 968/2104 =
-- 46.0% HP, Zeus hit him for 308 five seconds earlier, tidehunter is 1,565
-- away, and the TP he presses lands 12,646 units from his own fountain (i.e.
-- it is a forward TP, and this guard must not touch it either way).

tests['frame B: the control frame is the one GH #111 §2.3 retracted'] = function()
    local _, bot, heroes = load_fx(SLARDAR, { turbo = true, armed = true })
    assert(bot:GetUnitName() == 'npc_dota_hero_slardar', 'subject is Slardar')
    assert(math.abs(hp_pct(bot) - 0.460) < 0.005,
        'Slardar is at 46.0% HP (968/2104)')
    local tide = heroes['npc_dota_hero_tidehunter']
    local d = dist(bot, tide)
    -- MARGIN, stated because it is thin: 1,565 against a 1,600 ring is 35
    -- units. If a later dumper change moves the sampling phase (GH #107) this
    -- control can flip on that alone -- it is pinned on the ring, so read this
    -- line before trusting the frame.
    assert(d > 1500 and d < 1600,
        'tidehunter sits 1,565 away -- 35 units inside the ring, saw ' .. math.floor(d))
end

tests['frame B, gate ON: an enemy in the ring -> no veto'] = function()
    local J, bot = load_fx(SLARDAR, { turbo = true, armed = true })
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'somebody is 1,565 away: this retreat is not the P2 pattern')
end

tests['frame B: the ring is the deciding clause, and the bag is the second'] = function()
    local J, bot, heroes = load_fx(SLARDAR, { turbo = true, armed = true })
    -- The damage clause is quiet here: the Zeus bolt was 5.3s ago, outside the
    -- 3.0s window, so it cannot be credited with the refusal.
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == false,
        'no hero damage inside the window the guard reads')
    assert(bot:WasRecentlyDamagedByAnyHero(6.0) == true,
        'though there is some just outside it -- 5.3s, Zeus, 308 damage')
    -- Push tidehunter out of the ring and the guard STILL refuses, because
    -- Slardar carries echo_sabre/treads/quelling/wand/bracer and not one heal.
    local tide = heroes['npc_dota_hero_tidehunter']
    local vBot = bot:GetLocation()
    rawget(tide, '__spec').GetLocation = Vector(vBot.x + 2400, vBot.y, vBot.z or 0)
    rawset(tide, 'GetLocation', nil)
    assert(J.HasFieldRegenSource(bot) == false,
        'his six usable slots hold no flask/tango/faerie_fire/charged bottle')
    assert(J.ShouldRegenNotTpHome(bot) == false,
        'empty ring but nothing to drink -> still no veto')
    -- Give him a tango on top and only then does the frame qualify: proof by
    -- construction that BOTH clauses were doing work on the real frame.
    local slots = {}
    for i = 0, 16 do slots[i] = bot:GetItemInSlot(i) end
    local tango = { GetName = function() return 'item_tango' end }
    rawget(bot, '__spec').GetItemInSlot = function(_, i)
        if i == 5 then return tango end
        return slots[i]
    end
    rawset(bot, 'GetItemInSlot', nil)
    assert(J.HasFieldRegenSource(bot) == true, 'sanity: the tango is in a usable slot')
    assert(J.ShouldRegenNotTpHome(bot) == true,
        'empty ring + a heal in the bag is exactly the Lina shape')
end

tests['frame B: a backpack heal does not count'] = function()
    local J, bot = load_fx(SLARDAR, { turbo = true, armed = true })
    local slots = {}
    for i = 0, 16 do slots[i] = bot:GetItemInSlot(i) end
    local flask = { GetName = function() return 'item_flask' end }
    rawget(bot, '__spec').GetItemInSlot = function(_, i)
        if i == 7 then return flask end
        return slots[i]
    end
    rawset(bot, 'GetItemInSlot', nil)
    assert(bot:GetItemInSlot(7):GetName() == 'item_flask', 'sanity: it is in the backpack')
    assert(J.HasFieldRegenSource(bot) == false,
        'slots 6-8 are the backpack -- a salve there cannot be drunk')
end

-- ---------------------------------------------------------------------------
-- Wiring tripwire: the guard has to sit ON the 撤退:3 branch, and it has to
-- stay gated (director's #0b: an unreachable helper is worth nothing; the
-- charter's rule: a gated fix is not shipped, and a shipped one must not be
-- described as gated).

tests['wiring: the guard gates the 撤退:3 home TP'] = function()
    local f = assert(io.open('bots/ability_item_usage_generic.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local i = src:find('--第三种情况:只有一个敌人直接T回家', 1, true)
    assert(i, 'could not locate the 撤退:3 branch')
    local branch = src:sub(i, i + 2600)
    assert(branch:find('and not J%.ShouldRegenNotTpHome%( bot %)'),
        'the guard must be a clause of the 撤退:3 condition')
    assert(branch:find("sCastMotive = '撤退:3'", 1, true),
        'and the branch it guards must be the one that sets 撤退:3')
    local guard_at = branch:find('ShouldRegenNotTpHome', 1, true)
    local high_at = branch:find('return BOT_ACTION_DESIRE_HIGH', 1, true)
    assert(guard_at ~= nil and high_at ~= nil and guard_at < high_at,
        'the guard has to sit above the HIGH return it is meant to suppress')
end

tests['wiring: the guard is gated on turbo + stayfield'] = function()
    local f = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = f:read('*a')
    f:close()
    -- 2026-08-22T1x:xxZ: the predicate was split when the WALK half of owner
    -- priority P2 landed (mode_retreat_generic, soak id 'stayfield2'). The
    -- conditions moved into the ungated core J.ShouldRegenNotGoHome and each
    -- call site got its own thin gated wrapper.
    -- 2026-08-22T14:0xZ: split once more when the SUPPLY half landed (soak id
    -- 'fieldbuy'). The situation clauses now live one level further down, in
    -- J.IsFieldRegenSituation, because the supply lever asks the same question
    -- with the bag clause INVERTED. So the pin follows them: the situation
    -- half must stay turbo-only and keep its three radii, and
    -- ShouldRegenNotGoHome is now the situation plus the bag clause.
    local sit = src:match('function J%.IsFieldRegenSituation%(.-\nend')
    assert(sit, 'could not locate J.IsFieldRegenSituation')
    assert(sit:find('J%.IsModeTurbo%(%)'), 'turbo-only')
    -- The radii are read off the source so this test cannot drift into
    -- restating numbers the helper no longer uses.
    assert(sit:find('1600', 1, true), 'the ring the guarded branch measures')
    assert(sit:find('3000', 1, true), 'the attribution ring')
    assert(sit:find('1200', 1, true), 'the enemy-tower ring')
    local core = src:match('function J%.ShouldRegenNotGoHome%(.-\nend')
    assert(core, 'could not locate J.ShouldRegenNotGoHome')
    assert(core:find('J%.IsFieldRegenSituation%('), 'the core delegates the situation')
    assert(core:find('J%.HasFieldRegenSource%('),
        'and keeps the bag clause -- which is exactly what the supply lever inverts')
    local body = src:match('function J%.ShouldRegenNotTpHome%(.-\nend')
    assert(body, 'could not locate J.ShouldRegenNotTpHome')
    assert(body:find("J%.IsSoakCandidate%( 'stayfield' %)"), "gated on 'stayfield'")
    assert(body:find('J%.ShouldRegenNotGoHome%('), 'and it delegates to the core')
    -- Neither of the two ungated layers may grow a gate of its own, and an
    -- ungated CALLER of either would ship the behaviour.
    assert(not core:find('IsSoakCandidate', 1, true),
        'the core must stay gate-free; the gates belong on the wrappers')
    assert(not sit:find('IsSoakCandidate', 1, true),
        'the situation half must stay gate-free too')
    local _, nCallers = src:gsub('J%.ShouldRegenNotGoHome%(', '')
    assert(nCallers == 3, -- the definition + the two gated wrappers
        'J.ShouldRegenNotGoHome gained a caller outside the two wrappers; '
        .. 'that caller would be UNGATED. found ' .. nCallers)
end

-- ---------------------------------------------------------------------------
-- World assumptions this file runs under, written down rather than implied.

tests['[recorded] the consider function itself is not drivable here'] = function()
    local _, bot = load_fx(LINA, { turbo = true, armed = true })
    -- GH #89 (13th world assertion): GetActiveMode is bot-VM state, absent
    -- from every .dem, so `nMode == BOT_MODE_RETREAT` -- the outer condition
    -- of the whole retreat block -- is FALSE on every fixture. GH #100 (16th):
    -- J.CanCastAbility is false for every item handle, so the item loop never
    -- calls any ConsiderItemDesire at all. This file therefore pins the GUARD
    -- on a real frame and attributes the branch by elimination; it does not
    -- and cannot assert the final tpscroll desire.
    assert(bot:GetActiveMode() ~= BOT_MODE_RETREAT,
        'the retreat mode is unreachable on a fixture -- if this ever fails, '
        .. 'the mode gap was closed and this file can assert the desire directly')
end

tests['[recorded] the bottle leg of HasFieldRegenSource is unreachable here'] = function()
    local J, bot = load_fx(LINA, { turbo = true, armed = true })
    -- Lina literally carries a bottle on this frame -- an EMPTY one, which the
    -- dumper reads from the entity class CDOTA_Item_EmptyBottle, so the
    -- fixture names it 'empty_bottle' and the helper's name test already
    -- excludes it. Even a full one could not answer TRUE: the mock's
    -- GetCurrentCharges default is 0. The leg is source-pinned, not frame-pinned.
    local bBottle = false
    for i = 0, 5 do
        local it = bot:GetItemInSlot(i)
        if it ~= nil and it:GetName() == 'item_empty_bottle' then bBottle = true end
    end
    assert(bBottle, 'the empty bottle really is in a usable slot on this frame')
    assert(J.HasFieldRegenSource(bot) == true,
        'and the TRUE here comes from the faerie_fire, not from it')
end

return tests
