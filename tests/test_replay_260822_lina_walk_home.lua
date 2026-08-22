-- [stayfield2 / owner priority P2] The WALK half: the other route home.
--
-- Owner priority P2 asks for both home routes to be covered. The TP half
-- landed 2026-08-22T09:33Z as 'stayfield' (tests/test_replay_260822_lina_tp_home.lua,
-- the tpscroll 撤退:3 branch). The other route is mode_retreat_generic: when
-- its bid wins, the bot walks (or TPs) back to the fountain. That leg is not
-- unguarded -- J.ShouldStayAndRegen (PROMOTED, live in every turbo game) sits
-- on it at mode_retreat_generic:222 -- but it is blind on exactly the frame
-- P2 pins, for the same two reasons that made it blind on the item layer:
--   (1) its danger read is bot:WasRecentlyDamagedByAnyHero(3.0) with no
--       attribution, and 2.6s before the decision a Zeus 7,533 units away
--       landed a global ult on Lina, so "a hero damaged me" reads TRUE with
--       the nearest enemy 6,596 units off;
--   (2) its regen read is flask/tango-or-90-gold, and what Lina is carrying
--       is a faerie_fire.
-- Both are asserted below off the frame, not restated from the other file.
--
-- What this file can assert that its sibling could not: the FINAL DESIRE.
-- The item layer is unreachable on a fixture (GH #89 mode state, GH #100 item
-- Consider), so the TP half had to be pinned at the helper and attributed to
-- its branch by elimination. mode_retreat_generic.GetDesire() drives fine, so
-- here the measurement is the mode's own bid: 0.1441 shipped, 0 with the gate
-- armed, on the real frame.
--
-- Honest bound, stated first because it is the one that matters: on this frame
-- the retreat mode is the RUNNER-UP, not the winner (laning bids 0.369). So
-- what is measured here is a bid removed, not a bot turned around; the trip
-- home this frame actually took came from the item layer, which is the other
-- half's ('stayfield') call site. Both halves are needed for P2's DoD, which
-- is why they are armed together and gated apart.
--
-- The corpus sweep behind this file also produced the design's one real
-- surprise, and the tower clause in J.ShouldRegenNotGoHome exists because of
-- it: on f_260819_142047_zuus_ult_denied the predicate fired on a frame whose
-- retreat bid is ABSOLUTE*1.1 -- and that bid is NOT a trip home, it is
-- ShouldRun's 前期谨慎冲塔 tower-backoff. Suppressing it would have parked a
-- 40%-HP Zeus 727 units from an enemy tower. That frame is carried here as the
-- second negative control, with the deciding clause named.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local LINA = 'tests/fixtures/f_260822_063722_lina_tp_home.lua'
local SLARDAR = 'tests/fixtures/f_260822_063559_slardar_tp_forward.lua'
local ZUUS = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local RETREAT = 'bots/mode_retreat_generic.lua'
local LANING = 'bots/mode_laning_generic.lua'

local tests = {}

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, so a desire
-- comparison without these is a comparison of garbage (test_set.md §F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local SHIPPED_LINA_BID = 0.14413381588777
local SHIPPED_SLARDAR_BID = 0.85998018332327

local function read_file(path)
    local fh = assert(io.open(path, 'r'), 'cannot read ' .. path)
    local src = fh:read('*a')
    fh:close()
    return src
end

--- Install a fixture world for a bid-level drive.
--- opts.armed: soak id to arm (nil = shipped world, every gate off).
--- opts.lane_front: where GetLaneFrontLocation points (GH #61 refuses to
---   answer, so every bid-level test in this repo has to declare it; this one
---   also MEASURES that the answer does not matter -- see the mutation case).
--- opts.fresh_ping: withhold the GH #91 "nobody pinged defence" declaration,
---   so the corpus can measure whether the lazily-initialised stamp is
---   load-bearing here rather than assume it is not.
--- The game mode is read BY NAME, i.e. the way every shipped J.IsModeTurbo
--- caller reads it. The fifteenth world assertion (GH #93) showed the two
--- spellings disagree on 96 fixtures, so this file does not leave that
--- implicit: the sweep drives both readings and the [recorded] case below
--- asserts they agree on these two frames. No global is rawset here, so
--- nothing leaks into the next test file (the M16 lesson).
local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    local lf = opts.lane_front or 0
    GetLaneFrontLocation = function() return Vector(lf, lf, 0) end -- luacheck: ignore
    if not opts.fresh_ping then
        J.Utils['GameStates'] = J.Utils['GameStates'] or {}
        J.Utils['GameStates']['defendPings'] = { pingedTime = -1000 }
    end
    J.IsSoakCandidate = function(id)
        return opts.armed ~= nil and id == opts.armed
    end
    return J, bot, heroes, fx
end

--- One mode file's bid on the installed world.
local function bid_of(file)
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok, err = pcall(dofile, file)
    assert(ok, 'could not load ' .. file .. ': ' .. tostring(err))
    assert(type(GetDesire) == 'function', file .. ' exposes no GetDesire')
    local ok2, d = pcall(GetDesire)
    GetDesire, Think = nil, nil -- luacheck: ignore
    assert(ok2, file .. ' crashed on this frame: ' .. tostring(d))
    assert(type(d) == 'number', file .. ' returned a non-number')
    return d
end

local function bid(path, file, opts)
    world(path, opts)
    return bid_of(file)
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-9)
end

local function dist(a, b)
    local la, lb = a:GetLocation(), b:GetLocation()
    return math.sqrt((la.x - lb.x) ^ 2 + (la.y - lb.y) ^ 2)
end

local function hero_named(heroes, sName)
    for _, u in pairs(heroes) do
        if u:GetUnitName() == sName then return u end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Premise: this mode file really is drivable here. mode_farm_generic is not
-- (GH #91 found it crashes in GetRoshanDesire), so "the bid I measured" is a
-- claim that has to be earned per mode file, not assumed.
-- ---------------------------------------------------------------------------

tests['[premise] mode_retreat_generic drives on this fixture'] = function()
    local d = bid(LINA, RETREAT, {})
    assert(near(d, SHIPPED_LINA_BID),
        'shipped retreat bid on the pinned frame moved: got ' .. tostring(d))
end

-- ---------------------------------------------------------------------------
-- The frame. Only the facts this leg's argument rests on; the rest of the
-- ground truth is pinned in the sibling file and not restated here.
-- ---------------------------------------------------------------------------

tests['frame: Lina is at 31.8% HP with the nearest enemy 6,596 units away'] = function()
    local _, bot, heroes = world(LINA, {})
    local nHP = bot:GetHealth() / bot:GetMaxHealth()
    assert(near(nHP, 0.318, 0.001), 'HP moved: ' .. tostring(nHP))
    local nNearest = math.huge
    for _, u in pairs(heroes) do
        if u:GetTeam() ~= bot:GetTeam() and u:IsAlive() then
            nNearest = math.min(nNearest, dist(bot, u))
        end
    end
    assert(nNearest > 6000 and nNearest < 7000,
        'nearest enemy moved: ' .. tostring(nNearest))
end

tests['frame: the shipped veto is silent here -- blind spot 1, unattributed damage'] = function()
    local J, bot, heroes = world(LINA, {})
    assert(bot:WasRecentlyDamagedByAnyHero(3.0) == true,
        'the unattributed danger read is what makes the shipped veto bail')
    local zuus = hero_named(heroes, 'npc_dota_hero_zuus')
    assert(zuus ~= nil, 'the Zeus whose global ult lit that flag is on this frame')
    assert(bot:WasRecentlyDamagedByHero(zuus, 3.0) == true, 'and he is the dealer')
    assert(dist(bot, zuus) > 7000,
        'from 7,533 units away -- which is the whole point: a hero DAMAGED her, '
        .. 'no hero is ON her')
    -- The new core attributes it: same flag, dealer out of reach, no veto.
    assert(J.ShouldStayAndRegen(bot) == false, 'shipped veto: silent')
    assert(J.ShouldRegenNotGoHome(bot) == true, 'attributed core: fires')
end

tests['frame: the shipped veto is silent here -- blind spot 2, the regen read'] = function()
    local J, bot = world(LINA, {})
    -- J.ShouldStayAndRegen counts a flask, a tango buff, or 90 gold. Lina has
    -- none of the three; what she has is a faerie_fire, which the new
    -- inventory read (J.HasFieldRegenSource) does see. This clause is
    -- INDEPENDENTLY fatal to the shipped veto on this frame -- either blind
    -- spot alone would silence it, so neither can be called the reason
    -- without checking the other, which is what these two cases do.
    local bFlask = false
    for i = 0, 8 do
        local it = bot:GetItemInSlot(i)
        if it ~= nil and it:GetName() == 'item_flask' then bFlask = true end
    end
    assert(bFlask == false, 'no salve anywhere in the inventory')
    assert(bot:HasModifier('modifier_flask_healing') == false, 'no salve ticking')
    assert(bot:HasModifier('modifier_tango_heal') == false, 'no tango ticking')
    assert(bot:GetGold() < 90,
        'and she cannot buy one: gold is ' .. tostring(bot:GetGold()))
    assert(J.HasFieldRegenSource(bot) == true, 'but a heal IS in her bag')
end

-- ---------------------------------------------------------------------------
-- The measurement this file exists for: the mode's final desire.
-- ---------------------------------------------------------------------------

tests['bid: shipped 0.1441 -> 0 with stayfield2 armed'] = function()
    local dOff = bid(LINA, RETREAT, {})
    local dOn = bid(LINA, RETREAT, { armed = 'stayfield2' })
    assert(near(dOff, SHIPPED_LINA_BID), 'shipped bid: ' .. tostring(dOff))
    assert(dOn == BOT_MODE_DESIRE_NONE,
        'armed bid must be DESIRE_NONE, got ' .. tostring(dOn))
end

tests['bid: the two ids are independent -- stayfield alone does not move this leg'] = function()
    -- Same core predicate, two call sites, two soak ids. Arming one must not
    -- move the other: that non-independence is what the retreat guard chain
    -- was reordered to kill (GH #29), and it is what makes a per-id A/B mean
    -- anything at all.
    local d = bid(LINA, RETREAT, { armed = 'stayfield' })
    assert(near(d, SHIPPED_LINA_BID),
        "arming 'stayfield' moved the retreat bid: " .. tostring(d))
    local J, bot = world(LINA, { armed = 'stayfield2' })
    assert(J.ShouldRegenNotTpHome(bot) == false,
        "and arming 'stayfield2' must not switch on the TP half")
    assert(J.ShouldRegenNotWalkHome(bot) == true, 'only its own half')
end

tests['bid: honest bound -- retreat is the runner-up here, laning wins either way'] = function()
    -- What the gate removes on this frame is a bid, not a decision. Written
    -- down rather than left for a reader to assume the bot was turned around.
    local dRetreat = bid(LINA, RETREAT, {})
    local dLaning = bid(LINA, LANING, {})
    assert(dLaning > dRetreat, 'laning outbids retreat on the shipped frame')
    assert(near(dLaning, 0.369, 1e-9), 'laning bid moved: ' .. tostring(dLaning))
    local dLaningArmed = bid(LINA, LANING, { armed = 'stayfield2' })
    assert(near(dLaningArmed, dLaning),
        'and the gate does not touch the winner either')
end

-- ---------------------------------------------------------------------------
-- Mutations of the world this bid was measured in. The charter's rule (0z):
-- any case asserting a final bid runs the "move the lane front off the origin"
-- mutation first -- an assertion that fails under it is riding on the stub.
-- The GH #91 ping stamp gets the same treatment.
-- ---------------------------------------------------------------------------

tests['world: the retreat bid does not depend on where the lane front points'] = function()
    local d0 = bid(LINA, RETREAT, {})
    local d1 = bid(LINA, RETREAT, { lane_front = 4000 })
    assert(near(d0, d1),
        'the bid moved with the lane front (' .. tostring(d0) .. ' -> '
        .. tostring(d1) .. '), so this file is measuring the GH #61 stub')
    local dOn = bid(LINA, RETREAT, { armed = 'stayfield2', lane_front = 4000 })
    assert(dOn == BOT_MODE_DESIRE_NONE, 'and the gate still zeroes it')
end

tests['world: the retreat bid does not depend on the defendPings stamp'] = function()
    local d0 = bid(LINA, RETREAT, {})
    local d1 = bid(LINA, RETREAT, { fresh_ping = true })
    assert(near(d0, d1),
        'the fourteenth world assertion is load-bearing for this bid after all '
        .. '(' .. tostring(d0) .. ' -> ' .. tostring(d1) .. '); it must then be '
        .. 'declared as a measured premise, not a convenience')
end

-- ---------------------------------------------------------------------------
-- Negative control 1: the forward TP frame. The guarded branch legitimately
-- wins there and the core must stay out of its way -- with the deciding clause
-- named, not assumed.
-- ---------------------------------------------------------------------------

tests['control: on the forward-TP frame the bid stands at 0.86, armed or not'] = function()
    local dOff = bid(SLARDAR, RETREAT, {})
    local dOn = bid(SLARDAR, RETREAT, { armed = 'stayfield2' })
    assert(near(dOff, SHIPPED_SLARDAR_BID), 'shipped bid: ' .. tostring(dOff))
    assert(near(dOn, dOff), 'the gate must not touch a real retreat')
end

tests['control: TWO clauses veto that frame, so it is not a single-clause witness'] = function()
    local J, bot, heroes = world(SLARDAR, { armed = 'stayfield2' })
    -- Written this way because the mutation battery said so: shrinking the
    -- 1600 ring to 800 (M3) did NOT redden this case, and the reason is that
    -- the regen clause vetoes this frame too. Calling the ring "the" reason
    -- here would be the 0p mistake -- attributing to one clause on a frame
    -- where two are firing. Both are asserted; neither is called the reason.
    local nHP = bot:GetHealth() / bot:GetMaxHealth()
    assert(nHP > 0.18 and nHP < 0.55,
        'the HP band ADMITS this frame (' .. tostring(nHP) .. '), so it is not '
        .. 'among them -- if this ever fails the control has gone vacuous')
    local nNearest = math.huge
    for _, u in pairs(heroes) do
        if u:GetTeam() ~= bot:GetTeam() and u:IsAlive() then
            nNearest = math.min(nNearest, dist(bot, u))
        end
    end
    -- Veto 1: an enemy inside the ring. Margin declared: 1565 against a 1600
    -- ring is 35 units, so GH #107 (the dumper's sampling phase) could move
    -- this one on phase alone -- which is exactly why veto 2 matters.
    assert(nNearest < 1600, 'veto 1: an enemy is inside the ring: ' .. tostring(nNearest))
    assert(nNearest > 1500, 'and only just: ' .. tostring(nNearest))
    -- Veto 2: nothing drinkable in the bag. Independent of the ring, and NOT
    -- phase-fragile.
    assert(J.HasFieldRegenSource(bot) == false,
        'veto 2: this bot carries no field regen at all')
    assert(#bot:GetNearbyTowers(1200, true) == 0,
        'and the tower clause is NOT one of them here')
    assert(J.ShouldRegenNotGoHome(bot) == false, 'so the core stays silent')
    -- The ring's own isolated witness lives on the Lina frame in the sibling
    -- file ('frame A: the empty 1600 ring is load-bearing on its own'), which
    -- M3 does redden. This case deliberately does not duplicate that claim.
end

-- ---------------------------------------------------------------------------
-- Negative control 2: the frame that put the tower clause in the helper.
-- ---------------------------------------------------------------------------

tests['control: the tower-backoff frame -- every other clause admits it'] = function()
    local J, bot, heroes = world(ZUUS, { armed = 'stayfield2' })
    local nHP = bot:GetHealth() / bot:GetMaxHealth()
    assert(nHP > 0.18 and nHP < 0.55, 'HP band admits: ' .. tostring(nHP))
    local nNearest = math.huge
    for _, u in pairs(heroes) do
        if u:GetTeam() ~= bot:GetTeam() and u:IsAlive() then
            nNearest = math.min(nNearest, dist(bot, u))
        end
    end
    assert(nNearest > 7000,
        'the 1600 ring is empty by a mile: nearest enemy ' .. tostring(nNearest))
    assert(J.HasFieldRegenSource(bot) == true, 'and a tango is in the bag')
    -- ... so the ONLY clause that can be answering no is the tower ring.
    assert(J.ShouldRegenNotGoHome(bot) == false,
        'the core must decline this frame -- on the tower clause alone')
    local towers = bot:GetNearbyTowers(1200, true)
    assert(#towers >= 1, 'because an enemy tower is inside 1200')
    assert(dist(bot, towers[1]) < 900,
        'at ' .. tostring(dist(bot, towers[1])) .. ' units')
end

tests['control: and the bid it would have cancelled there is a tower-backoff, not a trip home'] = function()
    local _, bot = world(ZUUS, {})
    -- ShouldRun's 前期谨慎冲塔 clause: level <= 10, DotaTime() > 0, HP < 800,
    -- DotaTime() < 5*60, an enemy tower inside 898 -> return 2 -> the caller
    -- returns ABSOLUTE*1.1, the highest bid in the system. Each operand is
    -- asserted off the frame so the attribution is measured, not asserted by
    -- narration.
    assert(bot:GetLevel() <= 10, 'level: ' .. tostring(bot:GetLevel()))
    assert(DotaTime() > 0 and DotaTime() < 5 * 60,
        'inside the first five minutes: ' .. tostring(DotaTime()))
    assert(bot:GetHealth() < 800, 'health: ' .. tostring(bot:GetHealth()))
    assert(#bot:GetNearbyTowers(898, true) >= 1, 'enemy tower inside 898')
    local d = bid_of(RETREAT)
    assert(near(d, BOT_MODE_DESIRE_ABSOLUTE * 1.1),
        'the shipped bid on that frame is ABSOLUTE*1.1, got ' .. tostring(d))
    -- Armed, it stays exactly there -- which is the whole reason the tower
    -- clause exists.
    local dOn = bid(ZUUS, RETREAT, { armed = 'stayfield2' })
    assert(near(dOn, d), 'the gate must leave the tower backoff alone')
end

-- ---------------------------------------------------------------------------
-- Corpus. How often does this thing fire at all, and how often does it move
-- anything? Run in a subprocess (see tests/_stayfield_walk_sweep.lua).
-- ---------------------------------------------------------------------------

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_stayfield_walk_sweep.lua 2>/dev/null'))
    local out = p:read('*a')
    p:close()
    assert(out and out ~= '', 'the sweep produced nothing')
    return out
end

tests['[recorded] corpus: the predicate fires on 3 of 100 subject frames'] = function()
    local out = sweep()
    local nFix, nLive, nFires, nMoved =
        out:match('COUNT fixtures=(%d+) live=(%d+) fires=(%d+) moved=(%d+)')
    assert(nFix, 'the sweep did not report a COUNT line')
    assert(tonumber(nLive) == tonumber(nFix),
        'every fixture subject is alive on its own frame')
    -- A biased sample -- these fixtures were cut to pin OTHER decisions -- so
    -- this is a floor on rarity, not a domain size. The real frequency needs a
    -- declared batch wave, and that request goes with the family.
    assert(tonumber(nFires) == 3,
        'fires moved from 3; re-read the FIRE lines before touching this: ' .. out)
    assert(tonumber(nMoved) == 1,
        'the number of frames whose retreat bid MOVES changed: ' .. out)
    assert(out:find('FIRE f_260822_063722_lina_tp_home.lua', 1, true),
        'the pinned frame must be one of them')
end

tests['[recorded] corpus: the other two firing frames are already bidding zero'] = function()
    local out = sweep()
    -- Firing is not the same as changing anything: on both of these the
    -- retreat mode already wants nothing, so the gate is a no-op there. This
    -- is the difference between "the predicate is true" and "the behaviour
    -- moved", and it is why the count above tracks both numbers.
    for _, name in ipairs({ 'f_071859_qop_salve.lua',
                            'f_260819_182855_lion_drain_jungle.lua' }) do
        local off, on = out:match('FIRE ' .. name:gsub('%.', '%%.')
            .. ' [%d%.]+ ([%d%.]+) ([%d%.]+)')
        assert(off, 'no FIRE line for ' .. name .. ' in: ' .. out)
        assert(tonumber(off) == 0 and tonumber(on) == 0,
            name .. ' now bids ' .. off .. ' -> ' .. on .. '; it used to be a no-op')
    end
end

tests['[recorded] corpus: both game-mode readings agree on the two pinned frames'] = function()
    local out = sweep()
    -- The fifteenth world assertion (GH #93): by name the fixture world is
    -- Turbo, by the literal 23 it is not, and 18 of 96 fixtures change their
    -- WINNING mode between the two readings. This file reads by name. That is
    -- only safe if the two readings agree here, so the sweep drives both.
    for _, name in ipairs({ 'f_260822_063722_lina_tp_home.lua',
                            'f_260822_063559_slardar_tp_forward.lua' }) do
        local a, b, c, d = out:match('READING ' .. name:gsub('%.', '%%.')
            .. ' (%S+) (%S+) (%S+) (%S+)')
        assert(a, 'no READING line for ' .. name .. ' in: ' .. out)
        assert(a == c and b == d,
            name .. ': the two game-mode spellings disagree on this bid ('
            .. a .. '/' .. b .. ' by name, ' .. c .. '/' .. d .. ' honest), so '
            .. 'every bid in this file has to say which reading it is from')
    end
end

-- ---------------------------------------------------------------------------
-- Wiring tripwires. A gated fix that is not actually wired in is worth
-- nothing; a shipped one described as gated is worse.
-- ---------------------------------------------------------------------------

tests['wiring: the walk guard sits on the retreat mode and returns DESIRE_NONE'] = function()
    local src = read_file(RETREAT)
    local i = src:find('if J.ShouldRegenNotWalkHome(bot) then', 1, true)
    assert(i, 'the walk guard is not wired into mode_retreat_generic at all')
    local after = src:sub(i, i + 120)
    assert(after:find('return BOT_MODE_DESIRE_NONE', 1, true),
        'and it has to suppress the bid, not lower it')
    -- Above the guard chain, alongside the promoted J.ShouldStayAndRegen veto
    -- it extends -- NOT inside the chain, whose documented invariant is that
    -- its members are ordered by descending returned desire.
    local chain = src:find('RETREAT GUARD CHAIN: BEGIN', 1, true)
    local promoted = src:find('if J.ShouldStayAndRegen(bot) then', 1, true)
    assert(promoted and chain, 'could not locate the veto or the chain')
    assert(promoted < i and i < chain,
        'the walk guard must sit between the promoted regen veto and the chain')
end

tests['wiring: the walk guard is gated on stayfield2 and the comment says so'] = function()
    local src = read_file('bots/FunLib/jmz_func.lua')
    local body = src:match('function J%.ShouldRegenNotWalkHome%(.-\nend')
    assert(body, 'could not locate J.ShouldRegenNotWalkHome')
    assert(body:find("J%.IsSoakCandidate%( 'stayfield2' %)"), "gated on 'stayfield2'")
    assert(body:find('J%.ShouldRegenNotGoHome%('), 'and it delegates to the core')
    assert(not body:find("'stayfield'", 1, true),
        'the two halves must not share an id')
    -- test_gate_claim_consistency.lua enforces the reverse direction (a
    -- comment claiming a gate that does not exist). This is the forward one:
    -- the call site says INERT, so the gate had better be there.
    local mrg = read_file(RETREAT)
    local j = mrg:find('stayfield2', 1, true)
    assert(j, 'the call site names no gate')
    assert(mrg:sub(j, j + 900):find('INERT', 1, true),
        'the call site must say it is inert until armed')
end

tests['wiring: the core predicate has exactly the two gated callers'] = function()
    -- The core is deliberately gate-free, so a third caller anywhere would
    -- ship this behaviour into every turbo game. The sibling file pins the
    -- same count from the other side; both fail if a caller is added.
    local src = read_file('bots/FunLib/jmz_func.lua')
    local _, n = src:gsub('J%.ShouldRegenNotGoHome%(', '')
    assert(n == 3, 'definition + two wrappers = 3 occurrences, found ' .. n)
    local repo = read_file(RETREAT) .. read_file('bots/ability_item_usage_generic.lua')
    local _, m = repo:gsub('ShouldRegenNotGoHome', '')
    assert(m == 0, 'a call site calls the UNGATED core directly')
end

return tests
