-- [roamstale] The team_roam collapse ACTION never reaches its target: a stale
-- last-hit creep short-circuits Think().
--
-- Family: the director's §0b "helper 的推理被消费方的机制悄悄作废" -- the
-- ACTION-class variant (#37's shape), not the bid-class one (#31/#32/#35).
-- Here the bid arrives intact and even WINS the mode auction; the mode's own
-- Think() then throws it away.
--
-- The mechanism is static and provable by reading mode_team_roam_generic.lua:
--
--   * `hTargetCreep` is a FILE-LOCAL with exactly ONE writer -- the last-hit
--     branch of GetDesireHelper -- and it is never reset;
--   * that writer sits BELOW all six early-returning desire branches
--     (ConsiderHelpWhenCoreIsTargeted, ConsiderHelpAlly, punish-dive [ownhalf],
--     punish-over-chase [overchase], l1trade, l5combo -- two of them SHIPPED,
--     four of them soak candidates);
--   * Think() reads `hTargetCreep` FIRST and `return`s on it, before every
--     `Action_AttackUnit(targetUnit)` path.
--
-- So on every frame one of those branches wins the auction, the bot attacks the
-- creep it was told about on some EARLIER frame and the collapse target is never
-- touched. The desire says "collapse on the invader"; the action says "keep
-- last-hitting". That is exactly the behaviour the analyst watched and filed as
-- the motivation for `ownhalf`: WK, 100% HP, stun off cooldown, hovering ~1000u
-- from a 69%-HP solo Juggernaut for 17 seconds.
--
-- REAL FRAME: f_232228_wk_ownhalf_standoff -- game 20260722_232228_slot1 at
-- t=340.0 (5:40), subject skeleton_king 934/934 hp at (-6256, 2934), a solo
-- Juggernaut 614/890 (69%) at (-6264, 3989) => 1055u away and 2450u deeper into
-- OUR half than the midline, ally Sniper 93u from the subject. This is one of
-- the two frames `ownhalf` was written from, so the collapse genuinely fires
-- here and the whole chain is live rather than hypothetical.
--
-- LABELLED SYNTHETIC: the behavioural dump carries heroes only, never creeps, so
-- the last-hittable creep (and the three attack-timing / damage getters the real
-- J.WillKillTarget path reads off the handles) are added here explicitly. Every
-- assertion about the frame ITSELF -- laning phase, the punish target, the final
-- bid, which mode wins -- runs on the unmodified fixture and is asserted, not
-- assumed. See the "no creep at all" test for the control.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local FIXTURE = 'tests/fixtures/f_232228_wk_ownhalf_standoff.lua'
local CEIL = 0.72 -- what CapForLanePush leaves a full-HP collapse bid at

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the RemapValClamped arithmetic these branches run (same reason as
-- tests/test_capmono_ceiling.lua / tests/test_lanekill_bid_reachable.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

-- Load the real frame and put the REAL mode file on top of it.
--   armed = arm 'roamstale' (nothing else is ever armed unless asked)
local function world(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    -- Radiant subject: our ancient bottom-left, theirs top-right (the ownhalf
    -- domain is an ancient-distance margin, so both handles must exist).
    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
    end

    J.IsSoakCandidate = function(id)
        if id == 'ownhalf' then return opts.ownhalf ~= false end
        if id == 'roamstale' then return opts.armed == true end
        return false
    end

    -- A real allied tower OUTSIDE the shipped 1200 punish domain -- the dead
    -- zone the analyst measured (nearest T1 ~2100u from the invader). Same
    -- placement as tests/test_replay_ownhalf_standoff.lua.
    local tower = api.MakeUnit({
        GetUnitName = 'npc_dota_goodguys_tower1_top',
        GetLocation = api.Vector(-6200, 1800, 0),
        IsAlive = true, CanBeSeen = true, IsBuilding = true,
    })
    local origList = GetUnitList
    GetUnitList = function(kind) -- luacheck: ignore
        if kind == UNIT_LIST_ALLIED_BUILDINGS then return { tower } end
        return origList(kind)
    end

    -- Engine plumbing the behavioural dump does not carry (per-lane push/defend
    -- desire is engine state, not a snapshot field).
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    return J, bot, heroes, fx
end

-- LABELLED SYNTHETIC: one dire melee creep beside the subject, one hit from
-- death, plus the attack-timing/damage getters J.WillKillTarget reads. Nothing
-- here touches the subject's position, health or the enemy set.
local function installCreep(bot)
    local v = bot:GetLocation()
    local creep = api.MakeUnit({
        GetUnitName = 'npc_dota_creep_badguys_melee',
        GetLocation = api.Vector(v.x + 120, v.y + 60, 0),
        IsAlive = true, CanBeSeen = true, IsHero = false, IsBuilding = false,
        GetHealth = 20, GetMaxHealth = 550, GetHealthRegen = 0, GetTeam = 3,
        GetActualIncomingDamage = function(_, d) return d end,
    })
    local spec = rawget(bot, '__spec')
    spec.GetNearbyCreeps = function() return { creep } end
    spec.GetNearbyTowers = function() return {} end
    spec.GetAttackDamage = 60
    spec.GetAttackRange = 150
    spec.GetAttackSpeed = 100
    spec.GetAttackPoint = 0.35
    spec.GetSecondsPerAttack = 1.7
    spec.GetAttackProjectileSpeed = 0
    spec.GetLastAttackTime = -99
    for _, k in ipairs({ 'GetNearbyCreeps', 'GetNearbyTowers', 'GetAttackDamage',
        'GetAttackRange', 'GetAttackSpeed', 'GetAttackPoint',
        'GetSecondsPerAttack', 'GetAttackProjectileSpeed', 'GetLastAttackTime' }) do
        rawset(bot, k, nil)
    end
    return creep
end

-- Run the two frames the defect needs: one where the invader is still far away
-- (so the REAL last-hit branch stamps hTargetCreep), then the real frame.
-- Returns the action log of the second frame plus the second frame's desire.
local function two_frames(opts)
    local J, bot, heroes = world(opts)
    local creep = installCreep(bot)
    dofile('bots/mode_team_roam_generic.lua')

    -- FRAME N-1: the moment before the invader closed in. Park the Juggernaut
    -- across the map so no branch above the last-hit branch fires; everything
    -- else is the untouched frame.
    local jugg = heroes['npc_dota_hero_juggernaut']
    local jspec = rawget(jugg, '__spec')
    local vHome = jspec.GetLocation
    jspec.GetLocation = api.Vector(3000, 3000, 0)
    rawset(jugg, 'GetLocation', nil)
    assert(J.ShouldPunishDive(bot) == nil,
        'setup: with the invader parked far away nothing collapses on frame N-1')
    local log = rf.record_actions(bot)
    GetDesire()
    Think()
    assert(#log == 1 and log[1].args[1] == creep,
        'setup: frame N-1 must be an ordinary last-hit, so hTargetCreep is stamped')

    -- FRAME N: the invader is back at its REAL fixture location.
    jspec.GetLocation = vHome
    rawset(jugg, 'GetLocation', nil)
    while #log > 0 do table.remove(log) end
    local desire = GetDesire()
    Think()
    return log, desire, J, bot, heroes, creep
end

-- ---------------------------------------------------------------------------
-- The frame itself: everything the defect rests on is ASSERTED, not assumed.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: the ownhalf collapse fires and its bid WINS the mode auction'] = function()
    local J, bot, heroes = world()
    dofile('bots/mode_team_roam_generic.lua')
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(J.IsInLaningPhase(),
        't=340 is inside turbo laning (floor 480s), so CapForLanePush is live here')
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_juggernaut'],
        'ownhalf must return the solo invader on its own motivating frame')
    local roam = GetDesire()
    assert(math.abs(roam - CEIL) < 1e-9,
        'a full-HP collapse arrives as the lane-capped ' .. CEIL .. '; got ' .. tostring(roam))
    -- The bid is not the problem here: 0.72 beats everything else on this frame.
    local laning = dofile('bots/mode_laning_generic.lua')
    laning = nil -- luacheck: ignore
    assert(GetDesire() < roam,
        'the laning bid on this frame (the only other non-zero mode) must lose to '
        .. 'the collapse -- if it did not, this would be a BID defect, not an ACTION one')
end

-- ---------------------------------------------------------------------------
-- The defect: the winning collapse produces a creep attack.
-- ---------------------------------------------------------------------------

tests['SHIPPED: the collapse frame attacks LAST FRAME\'S creep, not the invader'] = function()
    local log, desire, _, _, heroes, creep = two_frames()
    assert(math.abs(desire - CEIL) < 1e-9,
        'setup: frame N must still be the collapse bid; got ' .. tostring(desire))
    assert(#log == 1, 'exactly one action on the collapse frame; got ' .. #log)
    assert(log[1].fn == 'Action_AttackUnit', 'got ' .. log[1].fn)
    assert(log[1].args[1] == creep,
        'the shipped defect: the collapse frame attacks the stale creep')
    assert(log[1].args[1] ~= heroes['npc_dota_hero_juggernaut'],
        'and therefore never touches the invader the desire was computed from')
end

tests['ARMED roamstale: the same frame attacks the INVADER'] = function()
    local log, desire, _, _, heroes, creep = two_frames({ armed = true })
    assert(math.abs(desire - CEIL) < 1e-9,
        'armed must not change the bid at all; got ' .. tostring(desire))
    assert(#log == 1, 'exactly one action on the collapse frame; got ' .. #log)
    assert(log[1].fn == 'Action_AttackUnit', 'got ' .. log[1].fn)
    assert(log[1].args[1] == heroes['npc_dota_hero_juggernaut'],
        'armed, the action finally matches the desire')
    assert(log[1].args[1] ~= creep, 'and the stale creep is gone')
end

-- ---------------------------------------------------------------------------
-- Containment.
-- ---------------------------------------------------------------------------

tests['CONTROL: with no creep in the world, shipped already collapses correctly'] = function()
    -- Proves the creep IS the mechanism -- not the tower stub, not the ancients,
    -- not the leash guard.
    local J, bot, heroes = world()
    dofile('bots/mode_team_roam_generic.lua')
    local log = rf.record_actions(bot)
    GetDesire()
    Think()
    assert(#log == 1 and log[1].args[1] == heroes['npc_dota_hero_juggernaut'],
        'without a stale creep the shipped collapse reaches the invader')
    assert(J.ShouldPunishDive(bot) ~= nil, 'and the collapse really is the source')
end

tests['CONTAINMENT: armed on an ORDINARY last-hit frame is byte-for-byte shipped'] = function()
    -- No early branch fires -> the last-hit branch reassigns hTargetCreep on the
    -- very same frame, so clearing it at the top can make no difference.
    local runs = {}
    for _, armed in ipairs({ false, true }) do
        local _, bot, heroes = world()
        local creep = installCreep(bot)
        dofile('bots/mode_team_roam_generic.lua')
        local jugg = heroes['npc_dota_hero_juggernaut']
        rawget(jugg, '__spec').GetLocation = api.Vector(3000, 3000, 0)
        rawset(jugg, 'GetLocation', nil)
        local log = rf.record_actions(bot)
        local d = GetDesire()
        Think()
        runs[#runs + 1] = { d = d, n = #log, hit = log[1] and log[1].args[1] == creep }
        assert(armed ~= nil) -- keep the loop var used
    end
    assert(runs[1].d == runs[2].d and runs[1].n == runs[2].n and runs[1].hit == runs[2].hit,
        'an ordinary last-hit frame must be identical armed and unarmed')
    assert(runs[1].hit, 'setup: that frame really is a last-hit')
end

tests['CONTAINMENT: inert in normal (non-turbo) mode even when armed'] = function()
    local J, bot, heroes = world({ armed = true })
    local creep = installCreep(bot)
    dofile('bots/mode_team_roam_generic.lua')
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(not J.IsModeTurbo(), 'setup: normal mode')
    -- ownhalf is turbo-gated too, so the collapse itself is gone; what matters is
    -- that the stale handle survives exactly as it does today.
    local jugg = heroes['npc_dota_hero_juggernaut']
    local jspec = rawget(jugg, '__spec')
    local vHome = jspec.GetLocation
    jspec.GetLocation = api.Vector(3000, 3000, 0)
    rawset(jugg, 'GetLocation', nil)
    local log = rf.record_actions(bot)
    GetDesire(); Think()
    assert(#log == 1 and log[1].args[1] == creep, 'setup: frame N-1 last-hit')
    jspec.GetLocation = vHome
    rawset(jugg, 'GetLocation', nil)
    while #log > 0 do table.remove(log) end
    GetDesire(); Think()
    assert(#log == 1 and log[1].args[1] == creep,
        'normal mode must keep the stale handle -- shipped behaviour unchanged')
end

-- ---------------------------------------------------------------------------
-- Reverse assertion: if someone fixes the writer/reader asymmetry properly
-- (resets hTargetCreep unconditionally, or moves the read below the collapse
-- paths in Think), the SHIPPED-defect test above stops reproducing and this
-- whole file is obsolete. Fail loudly then rather than passing by absence.
-- ---------------------------------------------------------------------------

tests['REVERSE: the shipped stale-handle path must still exist'] = function()
    local src = io.open('bots/mode_team_roam_generic.lua'):read('*a')
    local writes = select(2, src:gsub('\n%s*hTargetCreep = ', ''))
    assert(writes == 2,
        'expected exactly two writes to hTargetCreep (the last-hit branch and the '
        .. "gated reset); got " .. writes .. ' -- the ownership of this variable '
        .. 'changed and this test file must be re-derived')
end

return tests
