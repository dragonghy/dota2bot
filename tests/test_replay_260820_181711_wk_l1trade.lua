-- [strategy, GH #77] The ACTION layer of `l1trade`, on the frame the replay desk
-- nominated as its ⭐ pin -- and the ground truth that says that frame is NOT an
-- `l1trade` firing.
--
-- WHY THIS FILE EXISTS
--
-- GH #77 measured, over 32 mirror games, that inside `l1trade`'s own active band
-- the armed side auto-attacks 17.0pp LESS than baseline, and that the deficit
-- vanishes exactly inside the HP band where the branch's own arithmetic makes it
-- a provable no-op (HP < 0.4076). Its §3.2 sharpened the shape: the armed side is
-- not attacking someone ELSE and is not walking away -- on the frames its own
-- branch is bidding to open a fight, it issues no attack command at all. Its §4
-- nominated one frame to pin:
--
--   20260820_181711_slot1 (spot_20260820_180808_1_11a8de33..., s906, armed=radiant)
--   t=333.5, subject skeleton_king (p3, HP 0.752) -> jakiro (HP 0.399) at 83u.
--   "WK's entire output over t=330-343 is one hellfire_blast and its DoT ticks.
--    Auto-attacks: zero. He walked at melee range beside a 25-40% jakiro for 8
--    seconds and went from 0.75 to 0.09 himself."
--
-- The charter's rule for this family (backlog §8, added 2026-08-19T15:34Z) is:
-- once the BID assertion passes, go down one more layer and assert the ACTION.
-- `l1trade`'s bid layer was pinned by GH #31 (tests/test_lanekill_bid_reachable.lua);
-- its action layer had never been driven on a real frame. This file does that.
--
-- WHAT IT ESTABLISHES (each of these is an assertion below, not a claim)
--
--   1. Every clause of J.ShouldInitiateLaneKill that the behavioural dump CAN
--      answer passes on this frame: turbo, laning phase, IsCore, backed by a
--      >=40% ally (sniper at 545u, 54.7%), >=1 enemy inside 800 (jakiro 83,
--      juggernaut 539), self-risk 79 against a 526.5 bar, and both candidates
--      inside the depth leash (-908 / -435 ancient-distance: both dove into OUR
--      half). So this frame really is in the branch's addressable domain.
--
--   2. The helper STILL returns nil on the unmodified frame, and exactly one
--      clause is why: `J.GetTotalEstimatedDamageToTarget(tOurs, target)` is 0,
--      because the loader can only answer `GetEstimatedDamageToTarget` for
--      ENEMY -> subject (it is ground truth about the subject's incoming burst;
--      there is no such stream for our side's outgoing). That is GH #77 §2's
--      declared superset boundary, reproduced here as a mechanism assertion so
--      nobody re-derives it: grant that ONE getter and the helper fires.
--
--   3. With the lethality granted as a LABELLED SYNTHETIC, the action layer is
--      CLEAN. Armed: helper -> jakiro, GetDesire() = 0.92 (the GH #31 cap
--      exemption holds on a real frame), it beats every drivable competing mode,
--      and Think() emits exactly ONE order: Action_AttackUnit(jakiro, false).
--      No stale creep, no nil'd targetUnit, no missing action flag. Shipped:
--      bid 0, zero orders.
--      => GH #77 §3.2's "issues no attack command" is NOT produced inside
--      mode_team_roam_generic's consumer path.
--
--   4. GROUND TRUTH says the branch could not have fired here at all. The lethal
--      bar on this frame is jakiro's own health, 399 (see the note on regen
--      below). What our two heroes near jakiro ACTUALLY dealt him over the next
--      4 seconds, read off the replay's DAMAGE/CRITICAL_DAMAGE events, is 44 --
--      all of it sniper, none of it WK. (Another 110 landed from WK's skeletons
--      and a lane creep; `J.GetTotalEstimatedDamageToTarget` sums over heroes
--      only, so those do not count toward the bar either.) The engine's
--      cd/mana-aware estimate would have had to exceed realised output by ~9x
--      for the clause to pass.
--      => the ⭐ frame is a SUPERSET member, not a firing. WK's eight silent
--      seconds are real, but they are not `l1trade`'s action path, and this
--      frame must not be cited as "l1trade did this".
--
-- WHAT IT DOES NOT ESTABLISH
--
--   * Nothing about GH #77 §3's aggregate. A single frame cannot refute a
--     paired-seed -17.0pp with a measured noise floor; this file narrows WHERE
--     to look, it does not dispute THAT.
--   * Where the eight silent seconds DO come from. On the shipped side of this
--     frame team_roam bids 0 and emits nothing, which is correct -- the mode
--     that would be driving WK is mode_laning_generic, and that file cannot be
--     loaded on any fixture (GH #61: the loader refuses GetLaneFrontLocation).
--     Recorded below as an explicit named refusal, per the §0d discipline
--     ("in the modes that can be driven"), not as silence.
--   * TARGET ORDER. The candidate loop returns the FIRST enemy that clears the
--     bar in engine list order. Here that is jakiro (bar 399, mobile) while
--     juggernaut -- 160hp = 15%, stunned by WK's own hellfire_blast with 2.4s
--     left, 539u away, bar 160 -- sits in the same candidate list needing 2.5x
--     less burst. Standard play focuses the one that is already dying. That is
--     asserted below as a RECORDED observation only: its domain requires a burst
--     value at which BOTH candidates clear, which exists only under the labelled
--     synthetic, so it does not get a gate this round (same rule that kept
--     `lfcorelane` unarmed, 2026-08-20T15:30Z).
--
-- LOADER LIMITATION, DECLARED: the fixture carries no health regen, so
-- GetHealthRegen() answers 0 and the bar reads as exactly GetHealth(). Real
-- regen only RAISES the bar, so every "the bar was missed by" statement here is
-- a lower bound on the gap.
--
-- World-assertion compliance: #61 -- nothing here reads GetLaneFrontLocation
-- (the modes that would are named and asserted unloadable instead); #69 -- the
-- generator flagged neither ground_truth_ambiguous nor recent_damage_ambiguous
-- on this frame, so observed.burst is quotable; #58 -- nothing here consumes
-- GetTower; the fixture was generated with --roles from the game's own
-- analysis.json (s906), so J.GetPosition answers drafted positions.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FIXTURE = 'tests/fixtures/f_260820_181711_wk_l1trade_333.lua'
local WK   = 'npc_dota_hero_skeleton_king'
local JAK  = 'npc_dota_hero_jakiro'
local JUGG = 'npc_dota_hero_juggernaut'
local SNIP = 'npc_dota_hero_sniper'

-- Replay ground truth, read off the DAMAGE / CRITICAL_DAMAGE event stream of
-- 20260820_181711_slot1 over t in [333.5, 337.5]:
--   -> jakiro     : sniper 44, WK 0            (heroes: 44)
--                   WK's skeletons 82, lane creep 28 (not heroes, not counted)
--   -> juggernaut : WK 45 (hellfire_blast DoT ticks), sniper 69
-- WK's last auto-attack before the silence was at t=329.7 on JUGGERNAUT
-- (124 crit + 68, inflictor dota_unknown); his next is at t=343.1 on bristleback.
local REALISED_HERO_DAMAGE_ON_JAKIRO_4S = 44

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which ruins
-- the RemapValClamped arithmetic these branches run (same reason as
-- tests/test_capmono_ceiling.lua / tests/test_roamstale_collapse_action.lua).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

--- Load the real frame.
---   opts.armed   -- arm 'l1trade' (nothing else is ever armed)
---   opts.turbo   -- force J.IsModeTurbo() false, for the inertness control
---   opts.lethal  -- LABELLED SYNTHETIC: grant our two nearby heroes an
---                   outgoing-damage estimate of `opts.lethal` each, the one
---                   engine reader the dump cannot answer (see §2 of the header)
local function world(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    for k, v in pairs(DESIRE) do _G[k] = v end

    J.IsSoakCandidate = function(id) return opts.armed == true and id == 'l1trade' end
    if opts.turbo == false then
        J.IsModeTurbo = function() return false end
    end

    if opts.lethal ~= nil then
        for _, name in ipairs({ WK, SNIP }) do
            local sp = rawget(heroes[name], '__spec')
            sp.GetEstimatedDamageToTarget = function() return opts.lethal end
            rawset(heroes[name], 'GetEstimatedDamageToTarget', nil)
        end
    end

    -- Engine plumbing the behavioural dump does not carry (per-lane push/defend
    -- desire is engine state, not a snapshot field). Same shim as
    -- tests/test_roamstale_collapse_action.lua.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })

    return J, bot, heroes, fx
end

local function near(a, b, eps)
    return math.abs(a - b) <= (eps or 1e-9)
end

-- ---------------------------------------------------------------------------
-- 1. THE FRAME: every clause the dump can answer, measured and asserted.
-- ---------------------------------------------------------------------------

tests['FRAME: this really is a turbo laning frame with a core subject'] = function()
    local J, bot = world()
    assert(J.IsModeTurbo(), 'the dump is turbo')
    assert(near(DotaTime(), 333.5, 0.01), 'the fixture instant is t=333.5; got ' .. tostring(DotaTime()))
    assert(J.IsInLaningPhase(), 't=333.5 is inside turbo laning, so the branch is addressable at all')
    assert(J.IsCore(bot), 'l1trade is the CORE branch and WK must read as a core here')
    assert(J.GetPosition(bot) == 3,
        'drafted position from the fixture --roles (s906) is 3; got ' .. tostring(J.GetPosition(bot)))
    assert(bot.laneKiteUntil == nil, 'no kite suppression is standing on this frame')
end

tests['FRAME: the backing ally and the enemy candidate set are what GH #77 §4 says'] = function()
    local J, bot, heroes = world()

    local allies = J.GetNearbyHeroes(bot, 1000, false, BOT_MODE_NONE) or {}
    assert(#allies == 1 and allies[1] == heroes[SNIP],
        'exactly one ally inside 1000 -- sniper; got ' .. #allies)
    assert(near(GetUnitToUnitDistance(bot, heroes[SNIP]), 545.3, 0.2),
        'sniper is 545u away')
    assert(J.GetHP(heroes[SNIP]) >= 0.4,
        'sniper at ' .. string.format('%.3f', J.GetHP(heroes[SNIP]))
        .. ' clears the >=0.40 "backed" bar, so bBacked is genuinely true here')

    local enemies = J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}
    assert(#enemies == 2, 'two enemies inside 800; got ' .. #enemies)
    assert(near(GetUnitToUnitDistance(bot, heroes[JAK]), 83.2, 0.2), 'jakiro at 83u')
    assert(near(GetUnitToUnitDistance(bot, heroes[JUGG]), 538.9, 0.2), 'juggernaut at 539u')
    assert(J.CanBeAttacked(heroes[JAK]) and J.CanBeAttacked(heroes[JUGG]),
        'both candidates are attackable on this frame')
end

tests['FRAME: the self-risk clause passes, with real numbers'] = function()
    local J, bot, heroes = world()
    local nIncoming = 0
    for _, e in pairs(J.GetNearbyHeroes(bot, 800, true, BOT_MODE_NONE) or {}) do
        nIncoming = nIncoming + e:GetEstimatedDamageToTarget(true, bot, 3.0, DAMAGE_TYPE_ALL)
    end
    -- Ground truth (observed.burst): jakiro actually dealt WK 79 over the window;
    -- juggernaut dealt him nothing.
    assert(nIncoming == 79, 'incoming burst from the two candidates is 79; got ' .. nIncoming)
    local bar = bot:GetHealth() * 0.75
    assert(near(bar, 526.5), 'the self-risk bar is 0.75 * 702 = 526.5; got ' .. bar)
    assert(nIncoming < bar, 'self-risk passes with a wide margin, so it is not what blocks the branch')
end

tests['FRAME: both candidates are inside the depth leash (they dove into OUR half)'] = function()
    local J, _, heroes = world()
    local own, opp = GetAncient(GetTeam()), GetAncient(GetOpposingTeam())
    assert(own ~= nil and opp ~= nil, 'both ancients come from the fixture buildings stream')
    local function depth(h)
        return J.GetLocationToLocationDistance(h:GetLocation(), own:GetLocation())
             - J.GetLocationToLocationDistance(h:GetLocation(), opp:GetLocation())
    end
    -- Sign convention (docs + charter): >0 means past the midline on the ENEMY side.
    assert(near(depth(heroes[JAK]), -908.4, 0.5), 'jakiro depth -908; got ' .. depth(heroes[JAK]))
    assert(near(depth(heroes[JUGG]), -435.1, 0.5), 'juggernaut depth -435; got ' .. depth(heroes[JUGG]))
    assert(depth(heroes[JAK]) <= 800 and depth(heroes[JUGG]) <= 800,
        'the <=800 leash passes for both, so the leash is not what blocks the branch either')
end

-- ---------------------------------------------------------------------------
-- 2. THE ONE CLAUSE THE DUMP CANNOT ANSWER -- named, not hand-waved.
-- ---------------------------------------------------------------------------

tests['SUPERSET BOUNDARY: on the untouched frame the helper is blocked by the lethality getter alone'] = function()
    local J, bot, heroes = world({ armed = true })
    assert(J.ShouldInitiateLaneKill(bot) == nil,
        'armed, every answerable clause passing, the helper still returns nil')

    -- ...and this is exactly why: our side's outgoing estimate is structurally 0.
    for _, h in ipairs({ heroes[JAK], heroes[JUGG] }) do
        local tOurs = J.GetAlliesNearLoc(h:GetLocation(), 1000) or {}
        assert(#tOurs == 2, 'WK and sniper are both inside 1000 of each candidate')
        assert(J.GetTotalEstimatedDamageToTarget(tOurs, h) == 0,
            'the loader answers GetEstimatedDamageToTarget for ENEMY->subject only '
            .. '(GH #77 §2), so our combined burst reads 0 against ' .. h:GetUnitName())
    end
end

tests['SUPERSET BOUNDARY: granting that ONE getter is sufficient to make it fire'] = function()
    local J, bot, heroes = world({ armed = true, lethal = 400 })
    assert(J.ShouldInitiateLaneKill(bot) == heroes[JAK],
        'with the lethality granted and nothing else changed, the helper returns a target '
        .. '=> the lethality clause was the sole blocker')
end

-- ---------------------------------------------------------------------------
-- 3. GROUND TRUTH: the bar was missed by ~9x, so this frame is not a firing.
-- ---------------------------------------------------------------------------

tests['GROUND TRUTH: our heroes delivered 44 of the 399 the lethal clause demands'] = function()
    local J, _, heroes = world()
    local jak = heroes[JAK]
    -- The bar the branch actually evaluates. GetHealthRegen is 0 under the
    -- loader (declared limitation), so this is a LOWER bound on the real bar.
    local bar = jak:GetHealth() + jak:GetHealthRegen() * 4.0
    assert(bar == 399, 'the lethal bar on this frame is jakiro\'s 399 hp; got ' .. bar)
    assert(jak:GetHealthRegen() == 0,
        'declared: the fixture carries no regen, so 399 understates the real bar')

    assert(REALISED_HERO_DAMAGE_ON_JAKIRO_4S == 44,
        'replay ground truth: our two nearby heroes dealt jakiro 44 over the next 4s')
    assert(REALISED_HERO_DAMAGE_ON_JAKIRO_4S * 9 < bar,
        'the engine estimate would have had to beat realised hero output by more than 9x '
        .. 'for the clause to pass => the ⭐ frame is a SUPERSET member, not an l1trade firing')

    -- The same arithmetic for the enemy the branch did NOT pick, for contrast.
    assert(heroes[JUGG]:GetHealth() == 160,
        'juggernaut is at 160hp (15%) on this frame; got ' .. heroes[JUGG]:GetHealth())
    -- 114 realised on juggernaut vs a 160 bar -- within reach, unlike jakiro's 399.
    assert(heroes[JUGG]:GetHealth() * 2 < bar,
        'the enemy the loop passed over needed less than half the burst of the one it took')
end

-- ---------------------------------------------------------------------------
-- 4. THE ACTION LAYER (labelled synthetic lethality) -- clean.
-- ---------------------------------------------------------------------------

--- Drive the real mode file on the frame and return (bid, action log).
local function drive(opts)
    local J, bot, heroes = world(opts)
    dofile('bots/mode_team_roam_generic.lua')
    local bid = GetDesire()
    local log = rf.record_actions(bot)
    Think()
    return bid, log, J, bot, heroes
end

tests['ACTION: armed, the 0.92 survives the cap and Think emits ONE attack on the target'] = function()
    local bid, log, _, _, heroes = drive({ armed = true, lethal = 400 })
    assert(near(bid, 0.92),
        'the GH #31 lane-kill cap exemption holds on a real frame: 0.92, not the 0.72 cliff; got ' .. bid)
    assert(#log == 1, 'exactly one order is issued; got ' .. #log)
    assert(log[1].fn == 'Action_AttackUnit',
        'and it is an attack order, not a move; got ' .. log[1].fn)
    assert(log[1].args[1] == heroes[JAK],
        'aimed at the branch\'s own target -- no stale creep, no dropped targetUnit')
    assert(log[1].args[2] == false,
        'continuous form, as the shipped collapse pathway issues it')
end

tests['ACTION: shipped, team_roam bids nothing and emits nothing on this frame'] = function()
    local bid, log = drive({ armed = false, lethal = 400 })
    assert(bid == 0, 'gate OFF, team_roam has no reason to bid here; got ' .. bid)
    assert(#log == 0, 'and it issues no order at all; got ' .. #log)
end

tests['ACTION: non-turbo is inert even with the candidate armed'] = function()
    local bid, log = drive({ armed = true, turbo = false, lethal = 400 })
    assert(bid == 0, 'outside turbo the branch cannot fire; got ' .. bid)
    assert(#log == 0, 'and no order follows; got ' .. #log)
end

tests['ACTION: the 0.92 beats every mode that can be driven on this frame'] = function()
    local bid = drive({ armed = true, lethal = 400 })
    -- Fresh worlds per mode: a mode file that fails to load must not leave the
    -- previous file's GetDesire standing in for it.
    local drivable, refused = {}, {}
    for _, m in ipairs({
        'mode_assemble_generic', 'mode_assemble_with_humans_generic',
        'mode_attack_generic', 'mode_defend_tower_top_generic',
        'mode_defend_tower_mid_generic', 'mode_defend_tower_bot_generic',
        'mode_farm_generic', 'mode_laning_generic', 'mode_outpost_generic',
        'mode_push_tower_top_generic', 'mode_push_tower_mid_generic',
        'mode_push_tower_bot_generic', 'mode_retreat_generic', 'mode_roam_generic',
        'mode_roshan_generic', 'mode_rune_generic', 'mode_secret_shop_generic',
        'mode_side_shop_generic', 'mode_ward_generic',
    }) do
        world({ armed = true, lethal = 400 })
        _G.GetDesire = nil
        local ok = pcall(dofile, 'bots/' .. m .. '.lua')
        local v
        if ok and type(_G.GetDesire) == 'function' then ok, v = pcall(_G.GetDesire) end
        if ok and type(v) == 'number' then drivable[m] = v else refused[#refused + 1] = m end
    end

    for m, v in pairs(drivable) do
        assert(v < bid, m .. ' bids ' .. v .. ', which must lose to the lane-kill 0.92')
    end
    -- The only non-zero drivable competitor, asserted so a future change that
    -- moves it shows up here rather than silently.
    assert(near(drivable['mode_retreat_generic'], 0.4071, 1e-3),
        'retreat is the only non-zero competitor on this frame (0.407); got '
        .. tostring(drivable['mode_retreat_generic']))

    -- §0d discipline: name what could NOT be driven, so "it wins the auction"
    -- is read as "among the modes that can be driven".
    local names = table.concat(refused, ',')
    for _, m in ipairs({ 'mode_laning_generic', 'mode_defend_tower_top_generic',
                         'mode_push_tower_top_generic', 'mode_rune_generic' }) do
        assert(names:find(m, 1, true), m .. ' is expected to be undrivable on a fixture; '
            .. 'if it now loads, this test\'s "among drivable modes" caveat must be re-read. '
            .. 'Refused: ' .. names)
    end
    -- The one that matters most: WK's shipped-side driver is exactly the file
    -- GH #61 refuses, which is why this frame cannot say where the silence
    -- comes from -- only that it does not come from here.
    assert(names:find('mode_laning_generic', 1, true),
        'mode_laning_generic must be in the refused set (GH #61)')
end

-- ---------------------------------------------------------------------------
-- 5. RECORDED, NOT GATED: the candidate loop takes the first passer, not the
--    most killable one.
-- ---------------------------------------------------------------------------

tests['[recorded] the loop returns the 399hp mobile enemy over the 160hp stunned one'] = function()
    local J, bot, heroes = world({ armed = true, lethal = 400 })
    assert(J.ShouldInitiateLaneKill(bot) == heroes[JAK],
        'with a burst at which BOTH clear their bar, the loop returns jakiro')
    assert(heroes[JUGG]:GetHealth() < heroes[JAK]:GetHealth(),
        'while juggernaut -- the cheaper kill -- was in the same candidate list')
    assert(heroes[JUGG]:HasModifier('modifier_skeleton_king_hellfire_blast'),
        'and was carrying WK\'s own hellfire_blast at the time')
    -- Domain note: this contrast only exists at a burst value where both clear,
    -- which the dump cannot supply. No gate this round -- see the header.
    local _, _, _ = J, bot, heroes
end

return tests
