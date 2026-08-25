-- [towerfear] The early-tower-fear clause asks ONE question twice, and in turbo
-- only the wrong copy still answers.
--
-- THE CLAUSE. mode_retreat_generic.X.ShouldRun, "前期谨慎冲塔" block:
--
--     if botLevel <= 10 and DotaTime() > 0
--     and (#hEnemyHeroList > 0 or bot:GetHealth() < 800) then
--         if ( botLevel <= 5 or DotaTime() < 5 * 60 )        -- CRUDE
--             and nEnemyTowers[1] ~= nil then return 2 end
--         if botLevel <= 9 and nEnemyTowers[1] ~= nil        -- CALIBRATED
--             and nEnemyTowers[1]:CanBeSeen()
--             and nEnemyTowers[1]:GetAttackTarget() == bot
--             and #hAllyHeroList <= 1 then return 2 end
--     end
--
-- `botLevel <= 5` and `DotaTime() < 5*60` are two encodings of one predicate:
-- "am I still an early-game-fragile hero". In NORMAL mode they nearly coincide
-- -- a hero is around level 5 at 5:00, so the disjunction is close to a
-- restatement. TURBO DOUBLES XP, so the same wall-clock instant holds a level
-- 7-10 hero and the clock leg goes on firing for exactly the levels the level
-- leg has already released. And the return is not a nudge: ShouldRun's value
-- becomes BOT_MODE_DESIRE_ABSOLUTE * 1.1 in GetDesireHelper, which outbids
-- every other mode in the auction.
--
-- THE LEVER (one). Armed (turbo + soak candidate `towerfear`), the clock leg is
-- halved to the same RELATIVE maturity -- 2:30. Nothing else in the clause
-- moves, so the armed predicate is a SUBSET of the shipped one: this return can
-- only fire LESS often, never more.
--
-- WHY HALVING, and why it is not a number invented here (charter 0NUM). The
-- engine halves its own turbo phase timers, and this repository already mirrors
-- that halving wherever someone looked: Buff/NeutralItems.lua drops its four
-- neutral tiers at 8.5/13.5/18.5/30 in turbo against 17/27/37/60 in normal
-- (exactly 0.5 on all four), and J.IsEarlyGame is 5*60 turbo against 10*60
-- normal. The site's own sibling leg states the intended maturity; the fix
-- aligns the clock leg with it rather than inventing a new criterion.
--
-- AND THE CORPUS AGREES ON WHERE THAT BOUNDARY IS. Over 966 live hero frames:
-- in the window this halving releases (150s <= t < 300s) there are 206 frames,
-- mean level 4.60, of which 42 (20.4%) are ALREADY past the level leg; below
-- 150s there are 80 frames and NOT ONE is past it (0/80). 2:30 is where the
-- level-6 population begins in our own turbo games -- asserted below, both
-- directions.
--
-- DOMAIN, stated honestly and never added to an event rate (charter 0DOM).
-- These are FRAME counts on the fixture corpus, and the corpus is thin exactly
-- where this clause lives:
--   * an enemy tower inside ShouldRun's 898 ring:      32 / 966 frames (3.3%)
--   * the crude clause is ASKED (outer gate + tower):  17 frames
--   * it FIRES:                                         3 frames
--       - 2 held by the LEVEL leg (level 4 and level 5) -- armed is a no-op
--         there, and both are controls below;
--       - 1 held by the CLOCK leg alone -- the pin frame.
--   * so armed changes exactly ONE of 966 frames. That is a statement about
--     THIS corpus: our batch games self-terminate before sieges and these
--     fixtures were sampled for other reasons, so "standing at an enemy tower"
--     is under-sampled here relative to a real turbo game. The band the lever
--     acts on (levels 6-10, 2:30-5:00, tower within 898) is not rare in turbo
--     laning; it is rare in what we happened to freeze.
--
-- REAL FRAME (the pin): f_260819_142047_zuus_ult_denied -- game 20260819_142047
-- at t=278.5 (4:38). Radiant Zeus, level 7, 369/911 (40.5%), standing 727 from
-- an enemy tower, 9270 from his own fountain. No enemy hero within 1600 and no
-- ally within 1600 either; the outer gate admits him through its OTHER leg,
-- `bot:GetHealth() < 800`. The tower is NOT attacking him, so the calibrated
-- clause below is false and the release is real, not caught downstream.
-- Shipped bids 1.1 (ABSOLUTE * 1.1) and wins the auction outright; armed bids
-- -0.3616, the mode's ordinary health/mana computation on that frame.
-- GROUND TRUTH, recorded but NOT used as the argument: observed.burst is EMPTY
-- -- no enemy hero dealt this Zeus any damage in the following 5s -- and he
-- died 82.9s later, not inside the window the flee was protecting.
--
-- CONTROLS (the [reverse] half: the narrowing must not close the mechanism).
--   * f_260819_122930_lich_rescue_doomed / lina, level 4 at t=201.3 -- past the
--     ARMED clock (150) and held by the level leg. Armed must be identical.
--   * f_260819_183613_storm_collapse_parity / witch_doctor, level 5 at t=378.9
--     -- past the SHIPPED clock (300) entirely, still firing on the level leg.
--     Armed must be identical. Together these two pin that the halving touched
--     the clock leg and only the clock leg.
--   * f_260820_102030_wk_tower_in_reach / skeleton_king, level 8 at t=444.5,
--     tower at 787 -- the clause does not fire in either world.
--   * the pin frame with the clock wound back to 149: armed fires again. The
--     difference on the pin frame is the clock leg and nothing else.
--   * the pin frame in NORMAL mode with the candidate armed: identical to
--     shipped. The gate is turbo-only.
--
-- LIMITS (do not launder these away).
--   * `GetAssignedLane()` reads 0 on the pin frame, not LANE_MID, so the mid
--     override (1100/980 rings) is NOT exercised by any assertion here. The
--     lever does not touch it; a mid frame would use the same clause.
--   * The auction claim below is made against the mode files that can be driven
--     in the fixture world; undrivable ones are reported, not swallowed.
--   * The corpus cannot answer whether a tower would have killed this Zeus:
--     tower GetAttackDamage/GetAttackSpeed are not in the dump (pinned by
--     tests/test_fixture_nearby_structures.lua). This test therefore asserts
--     the DECISION, never the outcome.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local cs = require('corpus_scale')

local tests = {}

local F_PIN   = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local F_LVL4  = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua'
local F_LVL5  = 'tests/fixtures/f_260819_183613_storm_collapse_parity.lua'
local F_NOFIRE = 'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua'

local RETREAT = 'bots/mode_retreat_generic.lua'
local EPS = 1e-9

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes
-- a cross-mode desire comparison a comparison of garbage (test_set.md SS F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}

local function world(path, hero, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path, hero)
    for k, v in pairs(DESIRE) do _G[k] = v end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == (opts.id or 'towerfear')
    end
    if opts.normal_mode then GetGameMode = function() return 1 end end -- luacheck: ignore
    if opts.now ~= nil then
        local t = opts.now
        DotaTime = function() return t end -- luacheck: ignore
    end
    -- Per-lane push/defend desire is engine state, not a snapshot field.
    GetPushLaneDesire = function() return 0 end   -- luacheck: ignore
    GetDefendLaneDesire = function() return 0 end -- luacheck: ignore
    rawset(bot, 'PushLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    rawset(bot, 'DefendLaneDesire', { [LANE_TOP] = 0, [LANE_MID] = 0, [LANE_BOT] = 0 })
    -- GH #61: the loader refuses to answer GetLaneFrontLocation; the drivers
    -- still need a value. Map origin, explicitly.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    -- GH #91: an UNSET defendPings stamp is not "no ping", it is "pinged this
    -- instant" -- mode_farm_generic and aba_push stamp it with GameTime() on
    -- first read and then return NONE for 5s. Left undeclared, the auction
    -- below is run with farm and all three push modes silenced, and this file
    -- landed (2026-08-24T14:04Z) making an auction claim out of exactly that
    -- degenerate world. `stale` is the ordinary game state -- a defence ping is
    -- an event, not a condition -- so the readings are taken under it.
    rf.declare_defend_ping(J, 'stale')
    return J, bot, heroes, fx
end

--- The retreat mode's own bid on this frame.
local function retreat_bid(path, hero, opts)
    world(path, hero, opts)
    GetDesire, Think = nil, nil -- luacheck: ignore
    local ok, err = pcall(dofile, RETREAT)
    assert(ok, 'mode_retreat_generic failed to load -- ' .. tostring(err))
    local ok2, d = pcall(GetDesire)
    GetDesire, Think = nil, nil -- luacheck: ignore
    assert(ok2, 'mode_retreat_generic.GetDesire is not drivable on this frame -- '
        .. tostring(d))
    return d
end

local MODE_FILES = {}
do
    local p = io.popen('ls bots/mode_*.lua')
    for line in p:lines() do MODE_FILES[#MODE_FILES + 1] = line end
    p:close()
end

--- Every mode script's bid. Files that cannot be driven here are RETURNED, not
--- swallowed -- they are holes in any "who won the auction" claim.
local function auction(path, hero, opts)
    local bids, undrivable = {}, {}
    assert(#MODE_FILES >= 20, 'expected the full mode-file set; got ' .. #MODE_FILES)
    for _, f in ipairs(MODE_FILES) do
        world(path, hero, opts)
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
-- The source. Every constant the argument uses is read out of bots/, never
-- restated here (charter 0SRC/0CST).
-- ---------------------------------------------------------------------------

local SRC = (function()
    local fh = assert(io.open(RETREAT, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local BLOCK = (function()
    local at = assert(SRC:find('前期谨慎冲塔', 1, true),
        'the 前期谨慎冲塔 block lost its comment anchor')
    -- Byte length, so PROSE moves it: the 2026-08-25 GH #178 comment rewrite
    -- (the calibrated clause's real division of labour) added ~1.2 kB inside
    -- the block and pushed the calibrated clause past a 3400-byte window.
    -- Widened, not anchored to a later marker, because every assertion below
    -- wants the window to stop before the NEXT block.
    local block = SRC:sub(at, at + 4800)
    -- Self-witnessing window (charter 0LN2): if the window is too short, say
    -- THAT, instead of reporting "the clause disappeared" about a clause that
    -- is merely past the end of the substring.
    assert(block:find('nEnemyTowers%[1%]:GetAttackTarget%(%) == bot'),
        'the source window from 前期谨慎冲塔 no longer reaches the calibrated '
        .. 'clause -- widen it; the block itself may be intact')
    return block
end)()

tests['source: the gated clause is turbo-only, halves ONE leg, and the calibrated clause is untouched'] = function()
    local shipped = BLOCK:match('local nFearClock%s*=%s*(%d+)%s*%*%s*60')
    assert(shipped ~= nil, 'the shipped clock leg is no longer a nFearClock local with an N * 60 default')
    assert(tonumber(shipped) == 5, 'the shipped clock leg is no longer 5 * 60; re-derive the halving')

    local gate = BLOCK:match("J%.IsSoakCandidate%('([%w_]+)'%)%s*and%s*J%.IsModeTurbo%(%)")
    assert(gate == 'towerfear',
        'the gate is no longer "IsSoakCandidate(towerfear) and IsModeTurbo()" -- '
        .. 'a candidate that is not turbo-gated ships into normal games')
    assert(BLOCK:match('nFearClock%s*=%s*nFearClock%s*/%s*2') ~= nil,
        'the armed branch no longer halves the clock leg')

    -- The level leg must NOT be inside the gate: this is one lever.
    assert(BLOCK:match('botLevel%s*<=%s*5%s*or') ~= nil,
        'the level leg is no longer a bare `botLevel <= 5` -- if it moved too, '
        .. 'this is two levers, not one')
    assert(BLOCK:match('or%s*DotaTime%(%)%s*<%s*nFearClock') ~= nil,
        'the clock leg no longer compares DotaTime() against nFearClock with a '
        .. 'STRICT < -- a `<=` moves the boundary by one frame')

    -- and the calibrated clause underneath it, which is what catches the
    -- released frames, is still there with its four operands.
    for _, needle in ipairs({ 'botLevel <= 9', 'CanBeSeen%(%)',
                              'GetAttackTarget%(%) == bot', '#hAllyHeroList <= 1' }) do
        assert(BLOCK:find(needle),
            'the calibrated clause lost operand ' .. needle
            .. ' -- the released frames are no longer caught by it')
    end
end

-- ---------------------------------------------------------------------------
-- Premises of the pin frame. Every number the argument uses is asserted off
-- the frame itself.
-- ---------------------------------------------------------------------------

tests['REAL FRAME: turbo Zeus, level 7 at 4:38, 727 from a tower that is not shooting him'] = function()
    local J, bot, heroes, fx = world(F_PIN, 'npc_dota_hero_zuus')
    assert(J.IsModeTurbo(), 'the dump is turbo -- the gate is turbo-only')
    assert(math.abs(fx.time - 278.5) < EPS, 'pinned at t=278.5')
    assert(bot:GetUnitName() == 'npc_dota_hero_zuus' and bot:GetTeam() == 2,
        'subject is the Radiant Zeus')
    assert(bot:GetLevel() == 7, 'level 7 -- PAST the level leg (<= 5); got ' .. bot:GetLevel())
    assert(bot:GetHealth() == 369 and bot:GetMaxHealth() == 911, '369/911 = 40.5%')

    -- The outer gate admits him through its health leg, not its enemy leg.
    assert(#J.GetEnemyList(bot, 1600) == 0, 'no enemy hero within 1600')
    assert(bot:GetHealth() < 800, 'so the outer gate is carried by GetHealth() < 800')
    assert(#J.GetAllyList(bot, 1600) == 0, 'and no ally within 1600 either')
    assert(bot:GetLevel() <= 10, 'inside the outer level bound')

    local tw = bot:GetNearbyTowers(898, true)
    assert(#tw >= 1, 'an enemy tower stands inside ShouldRun 898 ring; got ' .. #tw)
    local d = GetUnitToUnitDistance(bot, tw[1])
    assert(d > 700 and d < 760, 'the tower is at ~727; got ' .. math.floor(d))
    assert(tw[1]:GetAttackTarget() ~= bot,
        'the tower is NOT attacking him -- this is what makes the CALIBRATED '
        .. 'clause false and the release real rather than caught downstream')

    -- ground truth, recorded, not argued from
    assert(fx.observed ~= nil and next(fx.observed.burst or {}) == nil,
        'observed.burst is empty: no enemy hero touched him in the next 5s')
    assert(math.abs((fx.observed.died_after or 0) - 82.9) < 0.05,
        'he died 82.9s later, outside the window the flee was protecting')
    assert(heroes ~= nil)
end

tests['PIN: shipped bids ABSOLUTE*1.1 and armed hands the frame back'] = function()
    local shipped = retreat_bid(F_PIN, 'npc_dota_hero_zuus')
    local armed   = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true })
    assert(math.abs(shipped - 1.1) < 1e-6,
        'shipped must bid BOT_MODE_DESIRE_ABSOLUTE * 1.1 here; got ' .. shipped)
    assert(armed < shipped - 0.5,
        'armed must fall back to the ordinary computation; got ' .. armed)
    assert(math.abs(armed - (-0.36159216360228)) < 1e-6,
        'the armed bid moved; re-read the frame before quoting the band. got ' .. armed)
end

tests['PIN: the difference IS the clock leg -- wind the clock back and armed fires again'] = function()
    local armed_now  = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true })
    local armed_back = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, now = 149.0 })
    assert(armed_now < 1.0, 'armed at t=278.5 does not fire')
    assert(math.abs(armed_back - 1.1) < 1e-6,
        'armed at t=149 (inside the halved leg) must fire exactly as shipped does; got '
        .. armed_back)
    -- and the shipped world is indifferent to that move, because 149 and 278.5
    -- are both inside its own leg.
    local shipped_back = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { now = 149.0 })
    assert(math.abs(shipped_back - 1.1) < 1e-6, 'shipped fires at t=149 too')
end

tests['PIN: the armed boundary is 150 exactly, and it is a strict <'] = function()
    -- Without these two, a mutation that widens the armed clock (say /1.2)
    -- passes every other assertion in this file: the pin frame at t=278.5 is
    -- still released and t=149 still fires. The boundary has to be pinned FROM
    -- BOTH SIDES or the only thing tested is its sign.
    local just_in  = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, now = 149.9 })
    local at_edge  = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, now = 150.0 })
    local just_out = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, now = 150.1 })
    assert(math.abs(just_in - 1.1) < 1e-6, 'armed must still fire at t=149.9; got ' .. just_in)
    assert(at_edge < 1.0,
        'the comparison is `<`, so t exactly 150 is OUTSIDE the armed leg; got ' .. at_edge)
    assert(just_out < 1.0, 'armed must not fire at t=150.1; got ' .. just_out)
end

tests['PIN: unarmed is the shipped world, and armed in NORMAL mode is too'] = function()
    local shipped = retreat_bid(F_PIN, 'npc_dota_hero_zuus')
    local other_id = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, id = 'someotherid' })
    assert(math.abs(shipped - other_id) < EPS,
        'arming a DIFFERENT candidate id changes this frame -- the gate reads the wrong id')
    local normal = retreat_bid(F_PIN, 'npc_dota_hero_zuus', { armed = true, normal_mode = true })
    assert(math.abs(shipped - normal) < EPS,
        'armed in normal mode differs from shipped -- the gate is not turbo-only')
end

tests['PIN: the auction winner changes, and nothing else in it moves'] = function()
    local bids_off, undrivable = auction(F_PIN, 'npc_dota_hero_zuus')
    local bids_on = auction(F_PIN, 'npc_dota_hero_zuus', { armed = true })
    local w_off, v_off = winner(bids_off)
    local w_on = winner(bids_on)
    assert(w_off == RETREAT and math.abs(v_off - 1.1) < 1e-6,
        'shipped: retreat wins outright at 1.1; got ' .. tostring(w_off) .. ' ' .. tostring(v_off))
    assert(w_on ~= RETREAT,
        'armed: retreat must no longer win the auction; it still does at ' .. tostring(bids_on[RETREAT]))
    local moved = {}
    for f, v in pairs(bids_off) do
        if f ~= RETREAT and math.abs((bids_on[f] or v) - v) > 1e-9 then moved[#moved + 1] = f end
    end
    assert(#moved == 0,
        'the gate moved a bid outside mode_retreat_generic: ' .. table.concat(moved, ', '))
    -- holes reported, not swallowed
    assert(type(undrivable) == 'table')
end

tests['PIN: the whole armed test set is indifferent to this bid -- only towerfear moves it'] = function()
    -- This frame is not new to the lab. The `stayfield2` proposal of
    -- 2026-08-22 (test_set.md, the 11:2xZ block) hit exactly it -- "7 级宙斯
    -- 40% 血、离敌方塔 727 码" -- from the SUPPLY side: its first predicate
    -- would have squashed this same ABSOLUTE*1.1 bid as a SIDE EFFECT, so that
    -- session narrowed its own fix with a tower clause and left a standing
    -- note: whoever moves this bid next must look at that line first. This is
    -- that move, made deliberately and on the clause's own merits -- so the
    -- separability has to be measured, not assumed.
    --
    -- The membership string is the 2026-08-24 test set (test_set.md line 2,
    -- minus the two that cannot be armed). It is quoted for a fact about
    -- bots/: none of these ids moves this frame's retreat bid.
    local SET = { 'l1trade', 'l5combo', 'midtp', 'suptp', 'tpcommit', 'tpdying',
        'lf_rescue', 'teambrain', 'ownhalf', 'overchase', 'fieldregen', 'wandbleed',
        'capmono', 'cmrguard', 'tpdead', 'zusult', 'blinkflee', 'liondrainstop',
        'creeppull', 'pullcamp', 'stayfield', 'stayfield2', 'fieldbuy', 'fieldcreep',
        'pullbeat' }
    -- Load a world per id-set through world(), then overwrite the single-id
    -- gate hook it installs with the multi-id version before driving the mode.
    local function bid(ids)
        local set = {}
        for _, id in ipairs(ids) do set[id] = true end
        local J = select(1, world(F_PIN, 'npc_dota_hero_zuus'))
        J.IsSoakCandidate = function(id) return set[id] == true end
        GetDesire, Think = nil, nil -- luacheck: ignore
        local ok, err = pcall(dofile, RETREAT)
        assert(ok, tostring(err))
        local ok2, d = pcall(GetDesire)
        GetDesire, Think = nil, nil -- luacheck: ignore
        assert(ok2, tostring(d))
        return d
    end

    local set_only = bid(SET)
    assert(math.abs(set_only - 1.1) < 1e-6,
        'the whole armed test set leaves this bid at ABSOLUTE*1.1; got ' .. set_only
        .. ' -- some other candidate now reaches this frame and the attribution '
        .. 'claim below is no longer clean')
    local with_tf = bid({ 'towerfear', unpack(SET) })
    local tf_only = bid({ 'towerfear' })
    assert(math.abs(with_tf - tf_only) < EPS,
        'towerfear inside the full armed string differs from towerfear alone ('
        .. with_tf .. ' vs ' .. tf_only .. ') -- the effect is not separable and '
        .. 'the wave cannot attribute it')
end

-- ---------------------------------------------------------------------------
-- Controls. The [reverse] half: the halving must not close the mechanism.
-- ---------------------------------------------------------------------------

tests['CONTROL level leg, past the armed clock: level 4 at t=201.3 is untouched'] = function()
    local J, bot, _, fx = world(F_LVL4, 'npc_dota_hero_lina')
    assert(math.abs(fx.time - 201.3) < 0.05, 'pinned at t=201.3')
    assert(bot:GetLevel() == 4, 'level 4 -- the LEVEL leg holds this frame')
    assert(fx.time > 150, 'and it is past the ARMED clock, so only the level leg can hold it')
    assert(#bot:GetNearbyTowers(898, true) >= 1, 'an enemy tower is in the ring')
    assert(J.IsModeTurbo())
    local shipped = retreat_bid(F_LVL4, 'npc_dota_hero_lina')
    local armed   = retreat_bid(F_LVL4, 'npc_dota_hero_lina', { armed = true })
    assert(math.abs(shipped - 1.1) < 1e-6, 'shipped fires here; got ' .. shipped)
    assert(math.abs(shipped - armed) < EPS,
        'armed must be bit-for-bit identical when the LEVEL leg holds the frame; got ' .. armed)
end

tests['CONTROL level leg, past the SHIPPED clock: level 5 at t=378.9 is untouched'] = function()
    local bot
    local _, b, _, fx = world(F_LVL5, 'npc_dota_hero_witch_doctor')
    bot = b
    assert(math.abs(fx.time - 378.9) < 0.05, 'pinned at t=378.9')
    assert(bot:GetLevel() == 5, 'level 5')
    assert(fx.time > 300, 'past the SHIPPED clock leg entirely -- the level leg is alone here')
    local shipped = retreat_bid(F_LVL5, 'npc_dota_hero_witch_doctor')
    local armed   = retreat_bid(F_LVL5, 'npc_dota_hero_witch_doctor', { armed = true })
    assert(math.abs(shipped - 1.1) < 1e-6,
        'shipped fires here on the level leg alone; got ' .. shipped)
    assert(math.abs(shipped - armed) < EPS,
        'armed changed a frame the clock leg was not holding; got ' .. armed)
end

tests['CONTROL no fire: level 8 at t=444.5 with a tower at 787 is untouched'] = function()
    local _, bot, _, fx = world(F_NOFIRE, 'npc_dota_hero_skeleton_king')
    assert(math.abs(fx.time - 444.5) < 0.05, 'pinned at t=444.5')
    assert(bot:GetLevel() == 8 and fx.time > 300,
        'neither leg holds this frame in either world')
    local shipped = retreat_bid(F_NOFIRE, 'npc_dota_hero_skeleton_king')
    local armed   = retreat_bid(F_NOFIRE, 'npc_dota_hero_skeleton_king', { armed = true })
    assert(math.abs(shipped - armed) < EPS,
        'armed moved a frame the clause never fired on; got ' .. shipped .. ' vs ' .. armed)
    assert(shipped < 1.1 - 1e-6,
        'this frame was supposed to be a NOFIRE row of the census; got ' .. shipped)
end

-- ---------------------------------------------------------------------------
-- The corpus census the domain paragraph above quotes. Run as a subprocess:
-- it rebuilds jmz_func once per hero-frame (~37s, zero AWS).
-- ---------------------------------------------------------------------------

local function sweep()
    local p = assert(io.popen('lua5.1 tests/_towerfear_sweep.lua 2>/dev/null'))
    local text = p:read('*a')
    p:close()
    assert(text:find('\nDONE\n') or text:find('^DONE\n'),
        'the corpus sweep subprocess did not finish (no DONE line)')
    local c, rows = {}, {}
    for line in text:gmatch('[^\n]+') do
        local k, v = line:match('^C ([%w_]+) (%-?%d+)$')
        if k then c[k] = tonumber(v) end
        local f, h, t, lvl, d, tag = line:match('^ROW (%S+) (%S+) ([%d%.]+) (%d+) (%d+) (%S+)')
        if f then
            rows[#rows + 1] = { fix = f, hero = h, t = tonumber(t),
                lvl = tonumber(lvl), d = tonumber(d), tag = tag }
        end
    end
    return c, rows
end

local SWEEP_C, SWEEP_ROWS = sweep()

tests['census: the corpus these numbers are quoted from'] = function()
    cs.corpus(SWEEP_C.fixtures, 'towerfear corpus')
    cs.ratchet(SWEEP_C.live, 966, 'live hero frames')
    -- constants read out of bots/ by the sweep: facts, so equalities.
    assert(SWEEP_C.src_outer_level == 10 and SWEEP_C.src_outer_hp == 800,
        'the outer gate moved; re-read the domain before quoting it')
    assert(SWEEP_C.src_near_ring == 898 and SWEEP_C.src_hero_ring == 1600,
        'ShouldRun rings moved; re-read the domain')
    assert(SWEEP_C.src_crude_level == 5 and SWEEP_C.src_crude_clock == 300,
        'the crude clause constants moved; the halving argument is about 5 and 5*60')
    assert(SWEEP_C.src_calib_level == 9, 'the calibrated clause level bound moved')
end

tests['census: what the clause does on real frames, both directions'] = function()
    cs.ratchet(SWEEP_C.tower_in_ring, 32, 'frames with an enemy tower inside 898')
    cs.ratchet(SWEEP_C.crude_reachable, 17, 'frames where the crude clause is ASKED')
    cs.ratchet(SWEEP_C.crude_fires, 3, 'frames where the crude clause FIRES')
    cs.ratchet(SWEEP_C.level_leg_holds, 2, 'firing frames held by the LEVEL leg')
    cs.ratchet(SWEEP_C.clock_only_fires, 1, 'firing frames held by the CLOCK leg alone')
    assert(SWEEP_C.crude_fires == SWEEP_C.level_leg_holds + SWEEP_C.clock_only_fires,
        'the two legs no longer partition the firing frames')
    -- The released frames are NOT caught by the calibrated clause: if this ever
    -- becomes non-zero, part of the lever is a no-op and the domain shrinks.
    assert((SWEEP_C.clock_only_but_calibrated or 0) == 0,
        'a clock-only frame is now also caught by the calibrated clause -- the '
        .. 'release is partly a no-op and the domain paragraph is stale')
    -- both directions of the ring (charter 0DIR): "no tower" is the common case
    -- and must be visible, not silent.
    assert(SWEEP_C.tower_absent + SWEEP_C.tower_in_ring == SWEEP_C.live,
        'the tower ring no longer partitions the live frames')
end

tests['census: the turbo fact the halving rests on -- 2:30 is where level 6 begins'] = function()
    cs.ratchet(SWEEP_C.band_half_to_full, 206, 'live frames in 150 <= t < 300')
    cs.ratchet(SWEEP_C.band_below_half, 80, 'live frames in t < 150')
    -- one in five heroes in the released window is ALREADY past the level leg
    local rate = SWEEP_C.band_half_to_full_lvl6plus / SWEEP_C.band_half_to_full
    assert(rate > 0.15,
        'the 150-300s window no longer holds a level-6+ population; the whole '
        .. 'premise ("turbo doubles xp so the clock leg outlives the level leg") '
        .. 'must be re-derived. rate = ' .. rate)
    -- and below 150s not one is: this is the assertion that picks 2:30 rather
    -- than some other fraction, so it stays an EQUALITY (growth-immune zero).
    assert((SWEEP_C.band_below_half_lvl6plus or 0) == 0,
        'a hero is now past the level leg before 2:30 -- the halved constant is '
        .. 'no longer the boundary the corpus supports; re-derive it')
    local mean = SWEEP_C.band_level_sum / SWEEP_C.band_half_to_full
    assert(mean > 4.0 and mean < 5.2,
        'the mean level in the released window moved off ~4.6; got ' .. mean)
end

tests['census: the three firing rows are the three frames this file pins'] = function()
    local fires = {}
    for _, r in ipairs(SWEEP_ROWS) do
        if r.tag ~= 'NOFIRE' then fires[#fires + 1] = r end
    end
    assert(#fires == SWEEP_C.crude_fires,
        'the ROW stream and the counters disagree about how many frames fire')
    local seen = {}
    for _, r in ipairs(fires) do seen[r.fix .. '/' .. r.hero] = r.tag end
    assert(seen['f_260819_142047_zuus_ult_denied/npc_dota_hero_zuus'] == 'CLOCKONLY',
        'the pin frame is no longer the clock-only frame')
    assert(seen['f_260819_122930_lich_rescue_doomed/npc_dota_hero_lina'] == 'LEVELLEG',
        'the level-4 control is no longer a level-leg frame')
    assert(seen['f_260819_183613_storm_collapse_parity/npc_dota_hero_witch_doctor'] == 'LEVELLEG',
        'the level-5 control is no longer a level-leg frame')
end

return tests
