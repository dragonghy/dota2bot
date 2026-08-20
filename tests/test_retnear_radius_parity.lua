-- [retnear] "Am I outnumbered here?" -- asked with the enemies counted over
-- four times the area of the allies.
--
-- mode_retreat_generic.GetDesireHelper builds both hero lists at 1600
-- (buildContext), and asks J.WeAreStronger(bot, 1600) alongside them. Then:
--
--     local nEnemyNearbyCount = #nEnemyHeroes            -- 1600
--     local nAllyNearbyCount  = #nAllyHeroes             -- 1600
--     ... unseenCount = alive enemies whose LAST-SEEN location is within
--                       3200 and no more than 5s old ...
--     if unseenCount > #nEnemyHeroes then nEnemyNearbyCount = unseenCount end
--
-- and every consumer underneath reads the result as "how many enemies are on
-- top of me":
--
--     if nEnemyNearbyCount - nAllyNearbyCount > 0 then  +0.1875 per surplus
--     if not bWeAreStronger and nEnemyNearbyCount >= nAllyNearbyCount then +0.25
--
-- After the overwrite the left side of both comparisons is a 3200-radius count
-- and the right side is a 1600-radius one. r=3200 is 4x the AREA of r=1600, so
-- the retreat bid is biased toward "outnumbered" as a matter of geometry, not
-- of the situation: an ally standing 1700 away does not offset an enemy 3100
-- away. 3200 is also past the bot's own day vision (1800) -- every enemy the
-- wide count adds beyond that is one a TEAMMATE can see, i.e. one that is near
-- the teammate, not near the bot.
--
-- ARMED: the count that may REPLACE the nearby count is taken at 1600, the
-- same radius as the two things it is weighed against. The wide count is still
-- computed and still feeds the "nothing around at all" discount further down
-- (`nEnemyNearbyCount == 0 and unseenCount == 0`), which legitimately wants a
-- wide horizon -- so exactly one lever moves. Armed can only lower or leave
-- the retreat bid, never raise it.
--
-- THE ROAD NOT TAKEN. The other way to make the comparison symmetric is to
-- widen the ALLY side to 3200. Rejected for this candidate: nAllyNearbyCount
-- also gates the Oracle / Dazzle / Satanic / Slark discount block below, so
-- widening it moves several levers at once, and the engine has no "last seen"
-- primitive for allies (they are never in fog to their own team) -- the two
-- sides would still not be the same measurement.
--
-- DOMAIN (measured, not guessed). Six turbo replays (20260820_0431xx-0437xx,
-- 43,256 hero-frames), reconstructing each team's vision from its own vision
-- sources (heroes 1800, creeps 750, towers 1900, observers 1600 -- the .dem
-- carries no fog bitmask, GH #27, so this is a model and is reported as one):
--   * the wide count overwrites the near count on 7,908 frames (18.3%);
--   * the retreat bid differs on 6,556 of them (15.2% of all frames), modal
--     delta 0.25, tail to 1.0 (delta 0.1875: 736, 0.25: 4892, 0.4375: 748,
--     0.625: 102, >=0.8125: 29);
--   * on 40 frames sampled from that set and driven through all 22 mode files,
--     the auction winner changes on 4 (10%).
--
-- REAL FRAME: f_260820_043637_axe_ring_alone -- game 20260820_043637_slot1 at
-- t=641.4 (10:41). Axe, Dire, 1548/1732 hp (89.4%), level 10, NO ally within
-- 1600 (nearest is 6465 away) and NO enemy within 1600 either -- three enemies
-- stand at 2974 (slardar), 3086 (obsidian_destroyer) and 3172 (skywrath_mage),
-- all inside the 1600-3200 ring. Shipped counts 3 enemies against 1 ally
-- (itself) and bids 0.690, which wins the auction. Armed counts 0 and bids
-- 0.065; mode_laning_generic's 0.369 wins instead.
-- GROUND TRUTH, recorded but NOT used as the argument: from t=641 the axe
-- walked back (-2335 -> -3727 -> -326 on x) and then stood still at
-- (-326, 5860) from t=655 to past t=675 at 97% health; no enemy hero dealt it
-- any damage in the following 5s (observed.burst is empty) and it did not die.
--
-- CONTROL FRAME: f_260820_043637_axe_ring_close -- same game, same hero, same
-- health (89%), t=393.4, with the geometry the other way round: skywrath 188
-- and slardar 741, i.e. INSIDE 1600. There the near count equals the wide
-- count and armed must be bit-for-bit identical.
--
-- SECOND FRAME: f_260820_043140_luna_ring_bid -- the honest half of the
-- footprint. Armed takes 0.4375 off the retreat bid (0.777 -> 0.339) and the
-- retreat mode STILL wins the auction, because nothing else on that frame bids
-- above 0.1. A lower bid is not automatically a changed decision.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local F_ALONE = 'tests/fixtures/f_260820_043637_axe_ring_alone.lua'
local F_CLOSE = 'tests/fixtures/f_260820_043637_axe_ring_close.lua'
local F_LUNA  = 'tests/fixtures/f_260820_043140_luna_ring_bid.lua'

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes
-- a cross-mode desire comparison a comparison of garbage (test_set.md §F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local RETREAT = 'bots/mode_retreat_generic.lua'
local EPS = 1e-9

local function world(path, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == (opts.id or 'retnear')
    end
    if opts.normal_mode then GetGameMode = function() return 1 end end -- luacheck: ignore
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    if opts.lane_front ~= nil then
        -- GH #61: the loader never wired GetLaneFrontLocation, so every lane
        -- front sits at the map origin for both teams. Any claim about the
        -- final auction has to survive moving it, or it is a claim about the
        -- stub. This is a MUTATION PROBE, not a reconstruction of the real
        -- lane front (which the dump cannot supply).
        GetLaneFrontLocation = function() -- luacheck: ignore
            return Vector(opts.lane_front[1], opts.lane_front[2], 0)
        end
    end
    return J, bot, heroes, fx
end

local MODE_FILES = {}
do
    local p = io.popen('ls bots/mode_*.lua')
    for line in p:lines() do MODE_FILES[#MODE_FILES + 1] = line end
    p:close()
end

--- Every mode script's bid on this frame, freshly loaded per file. Returns the
--- bid table plus the files whose GetDesire could NOT be driven in the fixture
--- world -- those are holes in any "who won the auction" claim, so they are
--- returned rather than swallowed.
local function auction(path, opts)
    local bids, undrivable = {}, {}
    assert(#MODE_FILES >= 20, 'expected the full mode-file set; got ' .. #MODE_FILES)
    for _, f in ipairs(MODE_FILES) do
        world(path, opts)
        GetDesire, Think = nil, nil -- luacheck: ignore
        local ok, err = pcall(dofile, f)
        assert(ok, 'mode file failed to load: ' .. f .. ' -- ' .. tostring(err))
        if type(GetDesire) == 'function' then
            local ok2, d = pcall(GetDesire)
            if not ok2 then
                undrivable[#undrivable + 1] = f .. ' :: ' .. tostring(d)
            elseif type(d) == 'number' then
                bids[f] = d
            end
        end
        GetDesire, Think = nil, nil -- luacheck: ignore
    end
    return bids, undrivable
end

local function winner(bids)
    local bn, bv = nil, -math.huge
    for f, v in pairs(bids) do
        if v > bv then bn, bv = f, v end
    end
    return bn, bv
end

-- ---------------------------------------------------------------------------
-- Premises. Every number this file argues from is asserted off the frame.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: alone at 89%, three enemies in the 1600-3200 ring'] = function()
    local J, bot, heroes, fx = world(F_ALONE)
    assert(J.IsModeTurbo(), 'the dump is turbo -- the gate is turbo-only')
    assert(math.abs(fx.time - 641.4) < EPS, 'pinned at t=641.4')
    assert(bot:GetUnitName() == 'npc_dota_hero_axe' and bot:GetTeam() == 3,
        'subject is the Dire axe')
    assert(bot:GetHealth() == 1548 and bot:GetMaxHealth() == 1732,
        '1548/1732 -- 89%, i.e. not a low-health retreat')
    assert(bot:WasRecentlyDamagedByAnyHero(5.0) == false,
        'no hero has touched it in 5s (the damage it is taking is creep damage)')

    local ring, near, ally = 0, 0, math.huge
    for _, u in pairs(heroes) do
        if u ~= bot and u:IsAlive() then
            local d = GetUnitToUnitDistance(bot, u)
            if u:GetTeam() ~= bot:GetTeam() then
                if d <= 1600 then near = near + 1
                elseif d <= 3200 then ring = ring + 1 end
            elseif d < ally then ally = d end
        end
    end
    assert(near == 0, 'no enemy is inside 1600; got ' .. near)
    assert(ring == 3, 'three enemies sit in the 1600-3200 ring; got ' .. ring)
    assert(ally > 6000, 'the nearest ally is 6465 away; got ' .. math.floor(ally))
end

tests['MECHANISM: the wide count is 3 and the same-radius count is 0'] = function()
    -- Driven through the engine readers the shipped loop uses, so this is the
    -- same arithmetic the mode file does, not a restatement of it.
    local _, bot = world(F_ALONE)
    local wide, samerad = 0, 0
    for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        if IsHeroAlive(id) then
            local info = GetHeroLastSeenInfo(id)
            local dInfo = info ~= nil and info[1] or nil
            if dInfo ~= nil and dInfo.time_since_seen <= 5.0 then
                local d = GetUnitToLocationDistance(bot, dInfo.location)
                if d <= 3200 then wide = wide + 1 end
                if d <= 1600 then samerad = samerad + 1 end
            end
        end
    end
    assert(wide == 3, 'shipped overwrites the nearby count with 3; got ' .. wide)
    assert(samerad == 0, 'at the radius everything else uses it is 0; got ' .. samerad)
end

-- ---------------------------------------------------------------------------
-- THE DEFECT, at the layer test_set.md §8 requires: the final bid, and the
-- auction it is decided in.
-- ---------------------------------------------------------------------------

tests['DEFECT: shipped bids 0.690 and wins; armed bids 0.065 and laning wins'] = function()
    local shipped, undrivable = auction(F_ALONE)
    local armed = auction(F_ALONE, { armed = true })

    -- The hole in this reconstruction, named rather than swallowed: one mode
    -- file cannot be driven on any fixture because the mock has no
    -- GetRuneSpawnLocation. Its bid is UNKNOWN in both worlds -- and identical
    -- in both, since this candidate does not touch it -- so the claim below is
    -- "of the mode files that can be driven". (Engine-owned modes are a second
    -- such hole: a .dem carries no mode, GH #27.)
    assert(#undrivable == 2, 'exactly two undrivable mode files expected; got '
        .. #undrivable .. ' -- ' .. table.concat(undrivable, ' | '))
    local joined = table.concat(undrivable, ' | ')
    assert(joined:find('mode_rune_generic', 1, true)
       and joined:find('GetRuneSpawnLocation', 1, true),
        'the rune mode, for the missing rune-spawn reader; got ' .. joined)
    assert(joined:find('mode_secret_shop_generic', 1, true)
       and joined:find('GetCourierState', 1, true),
        'and the secret-shop mode, for the missing courier-state reader; got '
        .. joined)

    assert(math.abs(shipped[RETREAT] - 0.69037509643389) < 1e-11,
        'shipped retreat bid; got ' .. tostring(shipped[RETREAT]))
    assert(math.abs(armed[RETREAT] - 0.06537509643389) < 1e-11,
        'armed retreat bid; got ' .. tostring(armed[RETREAT]))
    assert(math.abs((shipped[RETREAT] - armed[RETREAT]) - 0.625) < 1e-11,
        'the whole difference is 2 surplus enemies (2 * 0.1875) plus the 0.25 '
        .. '"not stronger and at least as many of them as us" clause')

    local sn, sv = winner(shipped)
    local an, av = winner(armed)
    assert(sn == RETREAT and math.abs(sv - 0.69037509643389) < 1e-11,
        'shipped: the retreat mode wins the frame; got ' .. tostring(sn))
    assert(an == 'bots/mode_laning_generic.lua' and math.abs(av - 0.369) < 1e-11,
        'armed: mode_laning_generic 0.369 wins instead; got ' .. tostring(an)
        .. ' ' .. tostring(av))

    -- Nothing else moved: this candidate touches one branch of one mode.
    for f, v in pairs(shipped) do
        if f ~= RETREAT then
            assert(math.abs((armed[f] or v) - v) < EPS,
                f .. ' changed too, so the footprint is wider than claimed')
        end
    end
end

tests['the flip is NOT riding on the stubbed lane front (GH #61)'] = function()
    -- Three different non-origin lane fronts. The probe is demonstrably live:
    -- it moves mode_defend_tower_top_generic from 0.1275 to 0.1 on this frame.
    for _, lf in ipairs({ { 3000, 3000 }, { -4000, 2000 }, { 6000, -6000 } }) do
        local shipped = auction(F_ALONE, { lane_front = lf })
        local armed = auction(F_ALONE, { armed = true, lane_front = lf })
        local sn = winner(shipped)
        local an, av = winner(armed)
        assert(sn == RETREAT, 'shipped still elects retreat with lane front at ('
            .. lf[1] .. ',' .. lf[2] .. '); got ' .. tostring(sn))
        assert(an == 'bots/mode_laning_generic.lua' and math.abs(av - 0.369) < 1e-11,
            'and armed still elects laning; got ' .. tostring(an))
        assert(math.abs(shipped[RETREAT] - 0.69037509643389) < 1e-11
           and math.abs(armed[RETREAT] - 0.06537509643389) < 1e-11,
            'the retreat mode itself never reads a lane front, so both bids are '
            .. 'bit-identical under the probe')
        local TOP = 'bots/mode_defend_tower_top_generic.lua'
        assert(math.abs(shipped[TOP] - 0.12750881244548) > 1e-6,
            'MUTATION IS LIVE: moving the lane front moves this bid off the '
            .. '0.1275 it has against the origin stub (the value it moves TO '
            .. 'depends on where the probe puts the front, which is the point '
            .. '-- it is a probe, not a reconstruction); got '
            .. tostring(shipped[TOP]))
    end
end

-- ---------------------------------------------------------------------------
-- Controls.
-- ---------------------------------------------------------------------------

tests['CONTROL FRAME: enemies really inside 1600 -> armed is bit-identical'] = function()
    local _, bot, heroes = world(F_CLOSE)
    local near = 0
    for _, u in pairs(heroes) do
        if u ~= bot and u:IsAlive() and u:GetTeam() ~= bot:GetTeam()
            and GetUnitToUnitDistance(bot, u) <= 1600 then near = near + 1 end
    end
    assert(near == 2, 'skywrath 188 and slardar 741 are inside 1600; got ' .. near)

    local shipped = auction(F_CLOSE)
    local armed = auction(F_CLOSE, { armed = true })
    for f, v in pairs(shipped) do
        assert(math.abs((armed[f] or v) - v) < EPS,
            'no bid may move on this frame; ' .. f .. ' did')
    end
    assert(math.abs(shipped[RETREAT] - (-0.41917013101233)) < 1e-11,
        'and the retreat bid is the same negative number in both worlds; got '
        .. tostring(shipped[RETREAT]))
end

tests['SECOND FRAME: the bid drops 0.4375 and the decision does not change'] = function()
    local shipped = auction(F_LUNA)
    local armed = auction(F_LUNA, { armed = true })
    assert(math.abs(shipped[RETREAT] - 0.77673395489822) < 1e-11,
        'shipped luna retreat bid; got ' .. tostring(shipped[RETREAT]))
    assert(math.abs(armed[RETREAT] - 0.33923395489822) < 1e-11,
        'armed luna retreat bid; got ' .. tostring(armed[RETREAT]))
    local sn = winner(shipped)
    local an = winner(armed)
    assert(sn == RETREAT and an == RETREAT,
        'retreat wins in BOTH worlds -- 0.339 still beats every other bid on '
        .. 'this frame (next is 0.1). Lower bid /= changed decision.')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
    local shipped = auction(F_ALONE, { normal_mode = true })
    local armed = auction(F_ALONE, { armed = true, normal_mode = true })
    assert(math.abs(armed[RETREAT] - shipped[RETREAT]) < EPS,
        'the gate is turbo-only; got ' .. tostring(armed[RETREAT]))
    -- ...and both are the SHIPPED number, not the armed one: an always-open
    -- gate would keep the two sides equal while quietly changing the value.
    -- NB the non-turbo bid is a different number from the turbo one
    -- (-0.0596 vs 0.690): other, already-promoted turbo-only behaviour sits in
    -- this same chain. What matters here is that it is the number the SHIPPED
    -- tree produces outside turbo, which an always-open gate would move.
    assert(math.abs(shipped[RETREAT] - (-0.05962490356611)) < 1e-11,
        'outside turbo the bid must still be the shipped one; got '
        .. tostring(shipped[RETREAT]))
end

tests['OFF: another candidate id does not arm this one'] = function()
    local shipped = auction(F_ALONE)
    local other = auction(F_ALONE, { armed = true, id = 'defnum' })
    assert(math.abs(other[RETREAT] - shipped[RETREAT]) < EPS,
        'arming defnum must leave the retreat bid alone; got ' .. tostring(other[RETREAT]))
    assert(math.abs(other[RETREAT] - 0.69037509643389) < 1e-11,
        'and the value both sides hold is the SHIPPED one -- this is what an '
        .. 'always-open gate fails; got ' .. tostring(other[RETREAT]))
end

-- ---------------------------------------------------------------------------
-- Source-level reverse assertions: they fail if the shape of the fix changes.
-- ---------------------------------------------------------------------------

tests['REVERSE: the wide count still feeds the "nothing around" discount'] = function()
    local src = io.open('bots/mode_retreat_generic.lua'):read('*a')
    assert(src:find('nEnemyNearbyCount == 0 and unseenCount == 0', 1, true),
        'the discount further down must keep reading the WIDE count -- if it '
        .. 'starts reading the narrow one this candidate moves two levers')
    assert(src:find('nSeenAugment > #nEnemyHeroes', 1, true),
        'and the augmentation must still be a max(), never a replacement')
end

tests['REVERSE: the two hero lists are still built at 1600'] = function()
    local src = io.open('bots/mode_retreat_generic.lua'):read('*a')
    assert(src:find('GetUnitToUnitDistance(bot, u) <= 1600', 1, true),
        'the whole argument is that 1600 is the radius the comparison is made '
        .. 'at; if buildContext changes radius, re-derive the candidate')
    assert(src:find('J.WeAreStronger(bot, 1600)', 1, true),
        'and that the power comparison beside it uses the same 1600')
end

-- ---------------------------------------------------------------------------
-- The limitation, asserted. When this fails, the fixture world has gained fog
-- and every "last seen" number measured here has to be re-read.
-- ---------------------------------------------------------------------------

tests['LIMITATION: the fixture world has no fog, so last-seen is maximal'] = function()
    local _, bot = world(F_ALONE)
    local seen = 0
    for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) do
        local info = GetHeroLastSeenInfo(id)
        local dInfo = info ~= nil and info[1] or nil
        if dInfo ~= nil then
            seen = seen + 1
            assert(dInfo.time_since_seen == 0,
                'every live enemy is reported as seen RIGHT NOW (GH #27: the '
                .. 'dump carries no per-team vision), so the >5s clause is '
                .. 'never exercised here and the domain numbers in the header '
                .. 'come from a vision MODEL over the .dem, not from a fixture')
        end
    end
    assert(seen >= 4, 'and every live enemy is reported; got ' .. seen)
    assert(bot:GetLevel() == 10, 'level 10 -- laning is long over on this frame')
end

return tests
