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
--
-- ===========================================================================
-- FRAMES HEALED 2026-08-22 (backlog 0b/0c; GH #45 director ruling of
-- 2026-08-21T19:0xZ, which re-graded this issue from "residual" to a blocking
-- follow-up on shipped default behaviour). Both fixtures were regenerated from
-- the same .dem with the current make_fixture.py: every position/HP/mana and
-- the whole ground truth reproduce byte for byte (burst DK 57, died_after
-- 181.6 / 175.6, no ground_truth_ambiguous), and the frames GAINED player_id,
-- 15 modifiers, 33 recent_damage events and the DRAFTED roles (seed 866,
-- armed=radiant -- the subject is on the armed side).
--
-- THE HEAL FLIPPED TWO OF THIS FILE'S ELEVEN CONCLUSIONS, both in the same
-- direction -- 'roamreach' is worth MORE and is MORE schedulable than recorded:
--
--   (1) "the chase is opened by ownhalf, and by ownhalf alone" is VOID. With
--       NOTHING armed at all the healed frame bids 0.72 and issues the same
--       continuous Action_AttackUnit(DK,false). The opener is ConsiderHelpAlly
--       -- ungated, shipped, default-on -- reached because the ally Centaur was
--       hit by that same DK 2.0s ago. The old attribution was an artefact of a
--       degenerate world: without recent_damage, WasRecentlyDamagedByHero is
--       false for everyone, so that branch could not fire on any fixture. The
--       defect is therefore LIVE IN SHIPPED TURBO PLAY, not gated behind a soak
--       candidate.
--   (2) "armed alone is a bit-for-bit no-op, never a lone bisect arm" is VOID.
--       Because the chase now exists with nothing armed, 'roamreach' armed ALONE
--       changes the order (AttackUnit -> bounded MoveToLocation). test_set.md
--       §I.7 constraint (1) no longer holds on this frame.
--
-- What did NOT move: the t=318.5 half (every branch silent, bid 0, order still
-- in force) is identical before and after the heal.
-- ===========================================================================

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

    -- LABELLED SYNTHETIC 2 RETIRED 2026-08-22: role used to be SET by hand here
    -- (`rawset(bot, 'assignedRole', 4)`, argued from the ward + arcane boots +
    -- blood grenade build). It was LOAD-BEARING, not decorative: measured on the
    -- pre-heal file, the loader answered pos 1 for all five allies (GH #53), so
    -- without the rawset the subject read as a CORE. The healed fixtures carry
    -- the DRAFTED role from the soak seed and it answers 4, so the hand-set value
    -- was right and is now redundant. It is ASSERTED, not set, in the role tests
    -- below; those also record what the intermediate derivation would have said.

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

tests['REAL FRAME: ownhalf is the only candidate that opens the PUNISH-DIVE branch'] = function()
    -- What survived the heal: among the soak ids, ownhalf and only ownhalf makes
    -- J.ShouldPunishDive return on this frame. What did NOT survive is the
    -- stronger claim this test used to make -- that the mode is therefore silent
    -- without it. See the next test.
    local names = { 'roamstale', 'overchase', 'l1trade', 'l5combo', 'capmono', 'roamreach' }
    for _, id in ipairs(names) do
        local J, bot = world(F_START, { ids = { [id] = true } })
        assert(J.ShouldPunishDive(bot) == nil,
            'only ownhalf may open the dive on this frame, but ' .. id .. ' did')
    end
    local J, bot, heroes = world(F_START, { ids = { ownhalf = true } })
    assert(J.ShouldPunishDive(bot) == heroes['npc_dota_hero_dragon_knight'],
        'ownhalf returns the DK on this frame')
    assert(math.abs(GetDesire() - CEIL) < 1e-9,
        'a full-HP collapse arrives as the lane-capped ' .. CEIL .. '; got ' .. GetDesire())
end

tests['HEAL FLIP 1: with NOTHING armed the shipped default already issues the chase'] = function()
    -- The headline correction. Before the heal this frame was silent unless
    -- ownhalf was armed; the healed frame drives the identical continuous order
    -- with an empty candidate set, i.e. in shipped turbo play.
    local log, desire, J, bot, heroes = frame(F_START, { ids = {}, castRanges = true })
    assert(J.ShouldPunishDive(bot) == nil, 'no candidate is armed, so no punish-dive')
    assert(J.ShouldPunishOverchase(bot) == nil, 'nor an over-chase punish')
    assert(J.ShouldInitiateLaneKill(bot) == nil, 'nor a lane kill')
    assert(math.abs(desire - CEIL) < 1e-9,
        'the ungated branch arrives at the same lane-capped ' .. CEIL .. '; got ' .. desire)
    assert(#log == 1 and log[1].fn == 'Action_AttackUnit'
        and log[1].args[1] == heroes['npc_dota_hero_dragon_knight'] and log[1].args[2] == false,
        'and it is the SAME continuous attack-follow on the DK that ownhalf produced')

    -- Which ungated branch: ConsiderHelpAlly, not ConsiderHelpWhenCoreIsTargeted.
    -- The core variant cannot be it -- J.GetClosestCore answers nil for this
    -- subject (see the [recorded] defect test below), and forcing it to nil
    -- leaves the bid untouched.
    local J2, bot2 = world(F_START, { castRanges = true })
    assert(J2.GetClosestCore(bot2, 3500) == nil,
        'GetClosestCore is nil here, so the core-targeted branch is not reachable')
    local J3, bot3 = world(F_START, { castRanges = true })
    J3.GetClosestCore = function() return nil end
    assert(math.abs(GetDesire() - CEIL) < 1e-9,
        'killing GetClosestCore outright must not move the bid -- it is HelpAlly that fires')
    -- and the reader HelpAlly does use is answered non-trivially on this frame,
    -- so the line above is not passing because both branches are dead.
    -- (compared by name: this is a third, independently loaded world, so the
    -- handles are not the same objects as `heroes` above.)
    local ally3 = J3.GetClosestAlly(bot3, 3500)
    assert(ally3 ~= nil and ally3:GetUnitName() == 'npc_dota_hero_centaur',
        'GetClosestAlly must answer the Centaur -- otherwise neither help branch is '
        .. 'reachable and this test proves nothing about which one fired; got '
        .. tostring(ally3 and ally3:GetUnitName()))
end

tests['HEAL FLIP 1, mechanism: the load-bearing input is recent_damage, inside a 2.5s window'] = function()
    -- ConsiderHelpAlly's decisive clause is
    --   nClosestAlly:WasRecentlyDamagedByHero(enemyHero, 2.5)
    -- and this frame sits 0.5s inside that window. Every other clause of the
    -- branch is asserted here too, so a future change to any of them fails loudly.
    local J, bot, heroes = world(F_START, { castRanges = true })
    local cent = heroes['npc_dota_hero_centaur']
    local dk   = heroes['npc_dota_hero_dragon_knight']

    assert(J.GetClosestAlly(bot, 3500) == cent, 'the closest ally within 3500 is the Centaur')
    assert(math.abs(dist(bot, cent) - 656) < 2, 'at 656u; got ' .. dist(bot, cent))
    assert(J.GetHP(bot) >= J.GetHP(cent), 'the subject is the healthier of the pair (1.00 vs 0.82)')
    assert(not J.IsCore(bot), 'and a support, so the core-only laning leash does not apply')
    assert(GetUnitToUnitDistance(dk, cent) <= 1600, 'the DK is within 1600 of the ally; got '
        .. GetUnitToUnitDistance(dk, cent))
    assert(#J.GetAlliesNearLoc(cent:GetLocation(), 1200) + 1
        >= #J.GetEnemiesNearLoc(cent:GetLocation(), 1600), 'and the numbers clause holds (2+1 vs 1)')

    -- The window, and the margin, measured rather than read off the source.
    assert(cent:WasRecentlyDamagedByHero(dk, 2.5), 'the 2.5s the branch actually asks for: TRUE')
    assert(cent:WasRecentlyDamagedByHero(dk, 2.0), 'the hit is exactly 2.0s old')
    assert(not cent:WasRecentlyDamagedByHero(dk, 1.9),
        'and not 1.9s -- so the branch clears its own constant by 0.5s, no more')

    -- HONESTY BOUNDARY (world assertion 13, GH #89): two of the branch's four
    -- outer clauses read mode predicates, and those are STRUCTURALLY constant on
    -- every fixture (GetActiveMode is bot-VM state, absent from any .dem). They
    -- are recorded as constants, not as findings about this frame.
    assert(J.IsGoingOnSomeone(bot) == false, 'constant-false on all fixtures, not measured here')
    assert(J.IsRetreating(bot) == false, 'constant-false on all fixtures, not measured here')
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

tests['HEAL FLIP 2: armed ALONE is not a no-op -- roamreach CAN be a lone bisect arm'] = function()
    -- Was: "armed alone is a bit-for-bit no-op (never a lone bisect arm)", which
    -- followed from flip 1's premise that no collapse means no order. With the
    -- shipped branch opening the chase by itself, arming roamreach and nothing
    -- else already changes the action. test_set.md §I.7 constraint (1) is void.
    local sLog, sD = frame(F_START, { ids = {}, castRanges = true })
    local aLog, aD, _, _, heroes = frame(F_START, { ids = { roamreach = true }, castRanges = true })

    assert(math.abs(sD - aD) < 1e-9, 'the BID is still untouched by the candidate; '
        .. sD .. ' vs ' .. aD)
    assert(#sLog == 1 and sLog[1].fn == 'Action_AttackUnit',
        'shipped-with-nothing-armed issues the continuous attack')
    assert(#aLog == 1 and aLog[1].fn == 'Action_MoveToLocation',
        'armed alone issues the bounded approach; got ' .. aLog[1].fn)
    local v = aLog[1].args[1]
    local dk = heroes['npc_dota_hero_dragon_knight']:GetLocation()
    assert(math.abs(v.x - dk.x) < 1e-9 and math.abs(v.y - dk.y) < 1e-9,
        'still aimed at the target, so the closing itself is unchanged')
end

tests['REVERSE: roamstale is no longer a live gate id at all'] = function()
    -- The isolation loop above arms 'roamstale' among the candidates. That id was
    -- PROMOTED on 2026-08-19 and no longer exists in bots/: the creep-handle reset
    -- is unconditional in turbo. Arming it is a no-op BY CONSTRUCTION, which is
    -- worth stating -- an isolation loop over a dead id proves nothing, and the
    -- day the id comes back (the GH #45 rollback path) this must be re-derived.
    local src = io.open('bots/mode_team_roam_generic.lua'):read('*a')
    assert(select(2, src:gsub("IsSoakCandidate%('roamstale'%)", '')) == 0,
        "bots/mode_team_roam_generic.lua gates something on 'roamstale' again -- the "
        .. 'candidate came back, so this file\'s isolation loop is live again and the '
        .. 'GH #45 re-gate path has been taken')
    assert(src:find('if J.IsModeTurbo() then\n        hTargetCreep = nil', 1, true) ~= nil,
        'the promoted (ungated, turbo-only) form of the reset must still be the shipped one')
end

-- ---------------------------------------------------------------------------
-- GH #105 / soak candidate 'corerole'. This block used to be a tripwire: it
-- asserted that jmz_func's `J.IsCore(bot)` defect (the loop runs over `member`
-- but role-tests the CALLER) was still present, precisely so that the day
-- somebody fixed it, flip 1's attribution would be re-derived instead of
-- silently re-routing to the core-targeted branch. The director fixed it on
-- 2026-08-22 behind the 'corerole' gate; this is the re-derivation the tripwire
-- was demanding. The helper's own contract lives in
-- tests/test_corerole_closest_core.lua -- what belongs HERE is only what the
-- correction does to this file's eleven conclusions.
--
-- Answer: with the gate OFF, nothing (that is what "gated" buys). With the gate
-- ARMED, the branch that opens the chase changes -- from ConsiderHelpAlly to
-- X.ConsiderHelpWhenCoreIsTargeted, which sits ABOVE it in Think -- while the
-- bid, the target and the order all stay identical ON THIS FRAME.
-- ---------------------------------------------------------------------------

tests['[GH #105] gate OFF: flip 1 is untouched, defect and all'] = function()
    local src = io.open('bots/FunLib/jmz_func.lua'):read('*a')
    local body = src:match('function J%.GetClosestCore%(bot, nRadius%)(.-)\nend')
    assert(body ~= nil, 'J.GetClosestCore must still exist in jmz_func')
    assert(body:find("IsSoakCandidate('corerole')", 1, true) ~= nil,
        'the correction must still be GATED -- if it ships by default, flip 1 is '
        .. 'attributed to the wrong branch in every turbo game and this whole '
        .. 'file must be re-measured')

    local log, desire, J, bot, heroes = frame(F_START, { ids = {}, castRanges = true })
    assert(not J.IsCore(bot), 'subject is a drafted support')
    assert(J.GetClosestCore(bot, 3500) == nil,
        'and with nothing armed it still gets nil, so the core-targeted branch '
        .. 'is still unreachable for it -- flip 1 is still ConsiderHelpAlly')
    local cent = heroes['npc_dota_hero_centaur']
    assert(J.IsCore(cent) and dist(bot, cent) < 3500,
        '...while a drafted core (Centaur, pos 3) is 656u away and alive')
    assert(math.abs(desire - CEIL) < 1e-9 and #log == 1
        and log[1].fn == 'Action_AttackUnit'
        and log[1].args[1] == heroes['npc_dota_hero_dragon_knight'],
        'and the frame ends exactly where HEAL FLIP 1 left it')
end

tests['[GH #105] ARMED: the opener re-routes to the core branch, same order'] = function()
    -- Isolation, not inference: disable ConsiderHelpAlly (a global in the mode
    -- file) and see which side of the gate can still produce the chase. Every
    -- world() re-dofiles the mode file, which re-installs the real one, but the
    -- last stub would otherwise outlive this test -- the runner is ONE Lua
    -- process for all 126 files -- so it is restored at the end.
    local realHelpAlly = ConsiderHelpAlly
    local J1, bot1 = world(F_START, { ids = {}, castRanges = true })
    ConsiderHelpAlly = function() return nil, false end -- luacheck: ignore
    local log1 = rf.record_actions(bot1)
    local d1 = GetDesire()
    Think()
    assert(d1 == 0 and #log1 == 0,
        'gate off, with HelpAlly disabled NOTHING is left: the core-targeted '
        .. 'branch is structurally unreachable for a support caller. got desire '
        .. tostring(d1) .. ' / ' .. #log1 .. ' orders')
    assert(J1.GetClosestCore(bot1, 3500) == nil, 'because the helper answers nil')

    local J2, bot2, heroes2 = world(F_START, { ids = { corerole = true }, castRanges = true })
    ConsiderHelpAlly = function() return nil, false end -- luacheck: ignore
    local log2 = rf.record_actions(bot2)
    local d2 = GetDesire()
    Think()
    assert(J2.GetClosestCore(bot2, 3500) == heroes2['npc_dota_hero_centaur'],
        'armed, the helper answers the Centaur')
    assert(math.abs(d2 - CEIL) < 1e-9,
        'and the core-targeted branch alone now carries the same ' .. CEIL
        .. ' bid; got ' .. tostring(d2))
    local ok = #log2 == 1 and log2[1].fn == 'Action_AttackUnit'
        and log2[1].args[1] == heroes2['npc_dota_hero_dragon_knight']
        and log2[1].args[2] == false
    ConsiderHelpAlly = realHelpAlly -- luacheck: ignore
    assert(ok, 'and issues the SAME continuous attack-follow on the DK')
end

tests['[GH #105] ARMED: this frame is observationally identical either way'] = function()
    local logOff, dOff, _, _, hOff = frame(F_START, { ids = {}, castRanges = true })
    local logOn, dOn, J, bot, hOn = frame(F_START, { ids = { corerole = true },
                                                     castRanges = true })
    assert(math.abs(dOff - dOn) < 1e-9, 'same bid: ' .. dOff .. ' vs ' .. dOn)
    assert(#logOff == 1 and #logOn == 1 and logOff[1].fn == logOn[1].fn
        and logOff[1].args[1] == hOff['npc_dota_hero_dragon_knight']
        and logOn[1].args[1] == hOn['npc_dota_hero_dragon_knight']
        and logOff[1].args[2] == logOn[1].args[2],
        'same order, same target, same continuous flag')

    -- HONEST BOUNDARY, and the reason the id is a candidate rather than a
    -- silent fix: the two branches do NOT share a desire formula. The
    -- core-targeted branch remaps HP over [0, 0.5] and HelpAlly over [0, 0.6]
    -- (mode_team_roam_generic.lua), so they only agree where both saturate --
    -- i.e. at HP >= 0.6. This subject is at full HP, which is why the frame
    -- shows a neutral re-route; it is a fact about the frame, not about the fix.
    assert(math.abs(J.GetHP(bot) - 1.0) < 1e-9,
        'the equality above rests on the subject being at full HP; got '
        .. J.GetHP(bot))
    local src = io.open('bots/mode_team_roam_generic.lua'):read('*a')
    assert(src:find('RemapValClamped(J.GetHP(bot), 0, 0.5, BOT_MODE_DESIRE_NONE, 0.98)', 1, true) ~= nil
        and src:find('RemapValClamped(J.GetHP(bot), 0, 0.6, BOT_MODE_DESIRE_NONE, 0.98)', 1, true) ~= nil,
        'the two ceilings (0.5 core-targeted, 0.6 help-ally) must still differ -- '
        .. 'if they are unified, the re-route becomes neutral at every HP and '
        .. 'this caveat can go')
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
-- The role heal itself (backlog 0c: every healed frame re-reads what it pinned).
-- ---------------------------------------------------------------------------

tests['ROLE HEAL: the drafted roles are carried, and the subject is pos 4 support'] = function()
    local fx = dofile(F_START)
    assert(type(fx.roles) == 'table', 'the healed fixture carries a drafted-role table')
    -- Radiant, seed 866. Written out so a regeneration that quietly changes the
    -- draft cannot pass unnoticed.
    local WANT = {
        npc_dota_hero_bristleback   = 1,
        npc_dota_hero_death_prophet = 2,
        npc_dota_hero_centaur       = 3,
        npc_dota_hero_shadow_shaman = 4,
        npc_dota_hero_zuus          = 5,
    }
    local seen = 0
    for hero, pos in pairs(WANT) do
        assert(fx.roles[hero] == pos, hero .. ' is drafted pos ' .. pos
            .. ', fixture says ' .. tostring(fx.roles[hero]))
        seen = seen + 1
    end
    assert(seen == 5, 'all five allied positions checked; got ' .. seen)

    local J, bot = world(F_START, { castRanges = true })
    assert(J.GetPosition(bot) == 4 and not J.IsCore(bot),
        'the chain answers pos 4 / support for the subject, from the draft')
end

tests['ROLE HEAL: the intermediate derivation is a CORE/SUPPORT flip on the subject'] = function()
    -- The measurement backlog 0c asks for. Three worlds for the same frame:
    --
    --   * PRE-HEAL, undoctored -- MEASURED this round by loading the old file:
    --     the loader answered pos 1 for ALL FIVE allies (the GH #53 degenerate
    --     state), subject included, so J.IsCore(subject) was TRUE. This file hid
    --     that behind `rawset(bot, 'assignedRole', 4)` -- i.e. the retired
    --     LABELLED SYNTHETIC 2 was LOAD-BEARING, not decorative, and every
    --     ally-role read in the chain ran on a constant.
    --   * player_id but no --roles (slot derivation): pid order on radiant is
    --     bristleback 0, death_prophet 1, SHADOW_SHAMAN 2, zuus 3, centaur 4, so
    --     the subject reads pos 3 = CORE. A core/support flip on the subject,
    --     and the reason this fixture had to skip the second debt tier rather
    --     than stop there. Confirmed live by mutation N3 (drop the roles table).
    --   * HEALED: pos 4, support, from the draft. Asserted live above.
    --
    -- The chase fires in all three, but not through the same clause: as a support
    -- the subject takes ConsiderHelpAlly's `not J.IsCore(bot)` leg, as a core it
    -- takes the `IsInRange(bot, ally, 1600)` leg (656u, so it also passes).
    -- => the outcome is stable under the heal, the MECHANISM is not. That is a
    -- per-frame measurement, never a reason to skip the next frame.
    local fx = dofile(F_START)
    local byPid = {}
    for _, u in ipairs(fx.units) do
        if u.team == 2 then byPid[#byPid + 1] = { pid = u.player_id, name = u.name } end
    end
    table.sort(byPid, function(a, b) return a.pid < b.pid end)
    assert(#byPid == 5, 'five radiant heroes; got ' .. #byPid)
    local slotPos
    for i, e in ipairs(byPid) do if e.name == fx.self then slotPos = i end end
    assert(slotPos == 3, 'slot-derivation puts the subject at pos ' .. tostring(slotPos)
        .. ' -- the point of this test is that it is 3 (core), not the drafted 4')
    assert(fx.roles[fx.self] == 4, 'while the draft says 4 (support)')

    -- The ally whose role the chase chain actually consumes moves too, and in the
    -- opposite direction: slot 5 (support) vs drafted 3 (core).
    assert(byPid[5].name == 'npc_dota_hero_centaur',
        'the Centaur is last in slot order; got ' .. byPid[5].name)
    assert(fx.roles['npc_dota_hero_centaur'] == 3, 'but drafted pos 3')
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
