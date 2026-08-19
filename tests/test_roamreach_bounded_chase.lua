-- [roamreach, GH #45] team_roam hands an unreachable hero target a CONTINUOUS
-- attack order, and that order outlives the desire that justified it.
--
-- Family: the director's §0b "helper 的推理被消费方的机制悄悄作废" -- the
-- ACTION-class variant, and a new sub-shape: the bid and the action are both
-- correct ON THEIR OWN FRAME; what is missing is any bound on how long the
-- action stays in force after the bid stops being made.
--
-- The mechanism, static and provable by reading the mode file:
--
--   * `Action_AttackUnit(hTarget, false)` is CONTINUOUS (docs/
--     BOT_API_REFERENCE.md: "keep attacking until the target dies or moves out
--     of range") -- the engine pursues until a NEW order arrives;
--   * the only release team_roam owns -- the >1800 leash at the top of Think --
--     lives inside Think, and the engine calls Think ONLY for the mode that
--     wins the auction;
--   * so on the first frame another mode outbids team_roam, the chase order
--     stops being re-evaluated AND stops being releasable, while it keeps
--     executing.
--
-- One frame of a true collapse branch therefore buys an unbounded chase.
--
-- REAL FRAMES: game 20260819_181742_slot1 (arm A of the roamstale bisect),
-- subject shadow_shaman (radiant support, top lane with Centaur):
--
--   f_260819_181742_ss_chase_start   t=312.5  the order is ISSUED (dist 805)
--   f_260819_181742_ss_chase_stalled t=318.5  6s later, NOTHING justifies it
--
-- Ground truth from the replay for the 12s in between (report
-- iterations/reports/strategy/20260819T213000Z.md): the bot covered ~3900u,
-- stayed in the 644-870u band the whole way, cast nothing and dealt zero damage
-- to any hero between t=305 and t=333, and the Dragon Knight it was chasing
-- regenerated 23% -> 42% HP.
--
-- LABELLED SYNTHETIC (declared, and every one of them ASSERTED where it
-- matters): the behavioural dump carries no attack ranges and no ability cast
-- ranges, so the mock answers 150 and 0. Both are wired here to Shadow Shaman's
-- REAL values (attack 400; Ether Shock 500, Shackles 400, Hex 550) -- that makes
-- the frame HARDER for the fix, not easier: 805u is out of reach on the real
-- numbers, not because of a mock default. Nothing else about the frame is
-- touched.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local tests = {}

local F_START   = 'tests/fixtures/f_260819_181742_ss_chase_start.lua'
local F_STALLED = 'tests/fixtures/f_260819_181742_ss_chase_stalled.lua'

local SS_ATTACK_RANGE = 400 -- real Shadow Shaman attack range
local SS_CAST_RANGE   = { shadow_shaman_ether_shock = 500,
                          shadow_shaman_shackles    = 400,
                          shadow_shaman_voodoo      = 550 } -- Hex, the longest
local CEIL = 0.72 -- what CapForLanePush leaves a full-HP collapse bid at

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the RemapValClamped arithmetic these branches run (same reason as
-- tests/test_roamstale_collapse_action.lua / tests/test_capmono_ceiling.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

--- Load one of the two real frames with the mode file on top of it.
--- opts.ids = set of armed soak ids. The batch that produced the observation had
--- 16 armed; the only two that matter to this chain are 'ownhalf' (which opens
--- the punish-dive branch on this frame -- verified below by isolation) and
--- 'roamreach' (this candidate).
local function world(path, opts)
    opts = opts or {}
    local ids = opts.ids or {}
    local J, bot, heroes, fx = rf.load(path)
    for k, v in pairs(DESIRE) do _G[k] = v end

    -- Radiant subject: our ancient bottom-left, theirs top-right (the punish
    -- domain is an ancient-distance margin, so both handles must exist).
    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
    end

    J.IsSoakCandidate = function(id) return ids[id] == true end

    -- Engine plumbing the behavioural dump does not carry (per-lane push/defend
    -- desire is engine state, not a snapshot field).
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    -- LABELLED SYNTHETIC 1: the real attack range (dump carries none).
    local spec = rawget(bot, '__spec')
    spec.GetAttackRange = SS_ATTACK_RANGE
    rawset(bot, 'GetAttackRange', nil)

    -- LABELLED SYNTHETIC 2: role. Role comes from the draft/lane assignment,
    -- neither of which is in a .dem; left alone the mock answers pos 2 (core).
    -- Shadow Shaman held radiant top with Centaur on sentry ward + arcane boots
    -- + blood grenade, i.e. the support of that pair.
    rawset(bot, 'assignedRole', 4)

    -- LABELLED SYNTHETIC 3 (opt-in): the real cast ranges, so the reach the fix
    -- computes is the hero's actual reach and not the mock's 0.
    if opts.castRanges then
        for _, u in pairs(fx.units) do
            if u.name == fx.self then
                for i, a in ipairs(u.abilities or {}) do
                    local r = SS_CAST_RANGE[a.name]
                    if r ~= nil then
                        local h = bot:GetAbilityInSlot(i - 1)
                        local aspec = rawget(h, '__spec')
                        aspec.GetCastRange = r
                        aspec.IsFullyCastable = true
                        rawset(h, 'GetCastRange', nil)
                        rawset(h, 'IsFullyCastable', nil)
                    end
                end
            end
        end
    end

    dofile('bots/mode_team_roam_generic.lua')
    return J, bot, heroes, fx
end

--- One frame, end to end: the real GetDesire() then the real Think().
local function frame(path, opts)
    local J, bot, heroes, fx = world(path, opts)
    local log = rf.record_actions(bot)
    local desire = GetDesire()
    Think()
    return log, desire, J, bot, heroes, fx
end

local function dist(bot, u) return GetUnitToUnitDistance(bot, u) end

-- ---------------------------------------------------------------------------
-- The frames themselves: every premise this file rests on is ASSERTED.
-- ---------------------------------------------------------------------------

tests['REAL FRAME t=312.5: full-HP support, 805u behind a 41% DK it cannot reach'] = function()
    local J, bot, heroes, fx = world(F_START, { castRanges = true })
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(J.IsInLaningPhase(), 't=312.5 is inside turbo laning (floor 480s)')
    assert(math.abs(fx.time - 312.5) < 1e-9, 'fixture pinned at t=312.5')
    assert(not J.IsCore(bot), 'subject is the support of the top pair (pos 4)')

    local dk = heroes['npc_dota_hero_dragon_knight']
    local cent = heroes['npc_dota_hero_centaur']
    assert(math.abs(dist(bot, dk) - 805) < 2, 'DK is 805u away; got ' .. dist(bot, dk))
    assert(math.abs(J.GetHP(bot) - 1.0) < 1e-9, 'subject is at FULL health')
    assert(math.abs(J.GetMP(bot) - 1.0) < 1e-9, 'subject is at FULL mana')
    assert(J.GetHP(dk) > 0.40 and J.GetHP(dk) < 0.42, 'DK at 41%; got ' .. J.GetHP(dk))
    assert(math.abs(dist(bot, cent) - 656) < 2, 'the ally Centaur is 656u away')

    -- The mechanism's own premise: NOTHING this hero owns reaches 805u.
    for _, r in pairs(SS_CAST_RANGE) do
        assert(r < dist(bot, dk),
            'premise: every real cast range (' .. r .. ') is short of the gap')
    end
    assert(SS_ATTACK_RANGE < dist(bot, dk), 'premise: the attack range is short too')
end

tests['REAL FRAME: the chase is opened by ownhalf, and by ownhalf alone'] = function()
    -- Attribution matters for scheduling: 'roamreach' is only ever REACHABLE on
    -- a frame some collapse branch already won, so it cannot be armed as a lone
    -- arm of a bisect (see the no-op test at the bottom).
    local names = { 'roamstale', 'overchase', 'l1trade', 'l5combo', 'capmono', 'roamreach' }
    for _, id in ipairs(names) do
        local J, bot = world(F_START, { ids = { [id] = true } })
        assert(J.ShouldPunishDive(bot) == nil,
            'only ownhalf may open the dive on this frame, but ' .. id .. ' did')
        assert(GetDesire() == 0, 'team_roam must be silent with only ' .. id .. ' armed')
    end
    local J, bot, heroes = world(F_START, { ids = { ownhalf = true } })
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_dragon_knight'],
        'ownhalf returns the DK on this frame')
    assert(math.abs(GetDesire() - CEIL) < 1e-9,
        'a full-HP collapse arrives as the lane-capped ' .. CEIL .. '; got ' .. GetDesire())
end

-- ---------------------------------------------------------------------------
-- The defect: the order is CONTINUOUS, and 6s later nothing justifies it.
-- ---------------------------------------------------------------------------

tests['SHIPPED t=312.5: the collapse issues a CONTINUOUS attack-follow at 805u'] = function()
    local log, desire, _, _, heroes = frame(F_START, { ids = { ownhalf = true }, castRanges = true })
    assert(math.abs(desire - CEIL) < 1e-9, 'the bid is the capped collapse')
    assert(#log == 1, 'exactly one order this frame; got ' .. #log)
    assert(log[1].fn == 'Action_AttackUnit', 'shipped orders an attack; got ' .. log[1].fn)
    assert(log[1].args[1] == heroes['npc_dota_hero_dragon_knight'], 'on the DK')
    assert(log[1].args[2] == false,
        'bOnce=false -- this is the CONTINUOUS form, the one that outlives the bid')
end

tests['REAL FRAME t=318.5: 6s later NO branch is true, the bid is 0, the bot is still 760u behind'] = function()
    local J, bot, heroes, fx = world(F_STALLED, { ids = { ownhalf = true, roamstale = true },
                                                  castRanges = true })
    assert(math.abs(fx.time - 318.5) < 1e-9, 'fixture pinned at t=318.5')
    local dk = heroes['npc_dota_hero_dragon_knight']
    assert(math.abs(dist(bot, dk) - 760) < 2, 'still 760u behind; got ' .. dist(bot, dk))
    assert(J.GetHP(dk) > 0.27 and J.GetHP(dk) < 0.29, 'DK now at 28%')

    -- Not one branch of the helper is true any more -- INCLUDING the one that
    -- started the chase. This is the whole defect: the action is still in force,
    -- its justification is gone, and the mode that owns the release is no longer
    -- the one being asked.
    assert(J.ShouldPunishDive(bot) == nil, 'punish-dive has stopped firing')
    assert(J.ShouldPunishOverchase(bot) == nil, 'no over-chase punish either')
    assert(J.ShouldInitiateLaneKill(bot) == nil, 'no lane kill')
    assert(J.ShouldSupportComboKill(bot) == nil, 'no support combo')
    assert(GetDesire() == 0,
        'team_roam bids 0 on the frame it is still chasing on; got ' .. GetDesire())

    -- ... and another mode outbids it, so team_roam's own >1800 leash is never
    -- reached again. (Laning is the only other non-zero bidder on this frame.)
    local roam = GetDesire()
    dofile('bots/mode_laning_generic.lua')
    assert(GetDesire() > roam,
        'another mode must be winning here -- that is why the leash never runs')
end

-- ---------------------------------------------------------------------------
-- Armed: same bid, BOUNDED order.
-- ---------------------------------------------------------------------------

tests['ARMED t=312.5: the same collapse issues a FINITE move order instead'] = function()
    local log, desire, _, _, heroes = frame(F_START,
        { ids = { ownhalf = true, roamreach = true }, castRanges = true })
    assert(math.abs(desire - CEIL) < 1e-9,
        'the BID is untouched (' .. CEIL .. '); this candidate changes no desire anywhere')
    assert(#log == 1, 'exactly one order this frame; got ' .. #log)
    assert(log[1].fn == 'Action_MoveToLocation',
        'armed must order a bounded approach; got ' .. log[1].fn)
    local v = log[1].args[1]
    local dk = heroes['npc_dota_hero_dragon_knight']:GetLocation()
    assert(math.abs(v.x - dk.x) < 1e-9 and math.abs(v.y - dk.y) < 1e-9,
        'the approach aims at the target position, so the closing is unchanged')
end

tests['ARMED: an IN-REACH target keeps the shipped continuous attack, byte for byte'] = function()
    -- Same frame, target dragged to 300u (declared synthetic: only the DK's
    -- position moves). Inside reach the commit is a promise we can keep, so the
    -- armed path must not touch it.
    local function run(ids)
        local J, bot, heroes = world(F_START, { ids = ids, castRanges = true })
        local dk = heroes['npc_dota_hero_dragon_knight']
        local v = bot:GetLocation()
        local dspec = rawget(dk, '__spec')
        dspec.GetLocation = api.Vector(v.x + 300, v.y, 0)
        rawset(dk, 'GetLocation', nil)
        assert(dist(bot, dk) < 400, 'setup: the target is now inside attack range')
        assert(J.ShouldPunishDive(bot) == dk, 'setup: the collapse still fires')
        local log = rf.record_actions(bot)
        local d = GetDesire()
        Think()
        return log, d
    end
    local sLog, sD = run({ ownhalf = true })
    local aLog, aD = run({ ownhalf = true, roamreach = true })
    assert(sD == aD, 'same bid')
    assert(#sLog == 1 and #aLog == 1, 'one order each')
    assert(aLog[1].fn == sLog[1].fn and aLog[1].fn == 'Action_AttackUnit',
        'in reach, armed must still order the attack; got ' .. aLog[1].fn)
    assert(aLog[1].args[2] == sLog[1].args[2] and aLog[1].args[2] == false,
        'and still the continuous form')
end

tests['ARMED: reach is the HERO\'S reach -- Hex (550) is what has to fall short'] = function()
    -- Without the declared cast ranges the mock answers 0 and the reach
    -- degenerates to the attack range. The defect must NOT depend on that: with
    -- the real 550 wired in, 805u is still out of reach and the fix still fires.
    local withCast = frame(F_START, { ids = { ownhalf = true, roamreach = true }, castRanges = true })
    local noCast   = frame(F_START, { ids = { ownhalf = true, roamreach = true } })
    assert(withCast[1].fn == 'Action_MoveToLocation' and noCast[1].fn == 'Action_MoveToLocation',
        'out of reach either way -- the verdict does not rest on a mock default')

    -- And the reach is genuinely read from the abilities: a synthetic 900-range
    -- castable ability (declared) brings 805u inside reach and hands the frame
    -- back to the shipped attack order.
    local J, bot, heroes = world(F_START, { ids = { ownhalf = true, roamreach = true } })
    local h = bot:GetAbilityInSlot(0)
    local aspec = rawget(h, '__spec')
    aspec.GetCastRange, aspec.IsFullyCastable, aspec.GetLevel = 900, true, 3
    rawset(h, 'GetCastRange', nil); rawset(h, 'IsFullyCastable', nil); rawset(h, 'GetLevel', nil)
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_dragon_knight'], 'setup: collapse fires')
    local log = rf.record_actions(bot)
    GetDesire(); Think()
    assert(#log == 1 and log[1].fn == 'Action_AttackUnit',
        'a 900-range ready ability makes 805u reachable, so the commit is legitimate again')
end

-- ---------------------------------------------------------------------------
-- Separability + domain: what armed can and cannot do.
-- ---------------------------------------------------------------------------

tests['SEPARABILITY: armed alone is a bit-for-bit no-op (never a lone bisect arm)'] = function()
    local log, desire = frame(F_START, { ids = { roamreach = true }, castRanges = true })
    assert(desire == 0, 'with no collapse armed the mode is silent')
    assert(#log == 0, 'and issues nothing at all -- the gate is unreachable alone')
end

tests['DOMAIN: normal mode (non-turbo) is untouched even with the id armed'] = function()
    local J, bot, heroes = world(F_START, { ids = { ownhalf = true, roamreach = true },
                                            castRanges = true })
    J.IsModeTurbo = function() return false end
    -- ownhalf is turbo-gated too, so drive the action path directly: force the
    -- collapse target through the shipped consumer and check the order type.
    J.ShouldPunishDive = function() return heroes['npc_dota_hero_dragon_knight'] end
    local log = rf.record_actions(bot)
    GetDesire()
    Think()
    assert(#log == 1 and log[1].fn == 'Action_AttackUnit' and log[1].args[2] == false,
        'outside turbo the continuous attack must survive; got '
        .. (log[1] and log[1].fn or 'no order'))
end

tests['DOMAIN: a NON-HERO target is never bounded, however far away it is'] = function()
    -- The same consumer, same frame, same 900u gap -- only the target's kind
    -- differs. LABELLED SYNTHETIC: a dire creep 900u away (the dump carries
    -- heroes only) fed through the shipped collapse consumer, so the ONLY thing
    -- under test is the guard's hero condition.
    local function run(ids)
        local J, bot = world(F_STALLED, { ids = ids, castRanges = true })
        local v = bot:GetLocation()
        local creep = api.MakeUnit({
            GetUnitName = 'npc_dota_creep_badguys_melee',
            GetLocation = api.Vector(v.x + 900, v.y, 0),
            IsAlive = true, CanBeSeen = true, IsHero = false, IsBuilding = false,
            GetHealth = 550, GetMaxHealth = 550, GetHealthRegen = 0, GetTeam = 3,
            IsAttackImmune = false, IsInvulnerable = false, IsMagicImmune = false,
        })
        J.ShouldPunishDive = function() return creep end
        assert(GetUnitToUnitDistance(bot, creep) > SS_CAST_RANGE.shadow_shaman_voodoo,
            'setup: the creep is beyond every reach this hero has')
        local log = rf.record_actions(bot)
        GetDesire()
        Think()
        return log, creep
    end
    local sLog = run({ ownhalf = true })
    local aLog, creep = run({ ownhalf = true, roamreach = true })
    assert(#sLog == 1 and sLog[1].fn == 'Action_AttackUnit',
        'setup: shipped attacks the out-of-reach creep')
    assert(#aLog == 1 and aLog[1].fn == 'Action_AttackUnit' and aLog[1].args[1] == creep
        and aLog[1].args[2] == sLog[1].args[2],
        'armed must leave non-hero targets byte-for-byte alone; got '
        .. (aLog[1] and aLog[1].fn or 'no order'))
end

-- ---------------------------------------------------------------------------
-- Reverse assertion: the day the CONTINUOUS order stops being the shipped form
-- here, or a release that survives the mode switch appears, this file's premise
-- is gone -- fail loudly then rather than passing by absence.
-- ---------------------------------------------------------------------------

tests['REVERSE: the shipped continuous-order path must still exist'] = function()
    local src = io.open('bots/mode_team_roam_generic.lua'):read('*a')
    local n = select(2, src:gsub('Action_AttackUnit%(targetUnit, false%)', ''))
    assert(n == 2,
        'expected exactly two continuous hero-attack orders in team_roam Think '
        .. '(help-ally and core/support); got ' .. n
        .. ' -- the order set changed and this test file must be re-derived')
end

return tests
