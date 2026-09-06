-- [towerring] `towerfear` halves the early-tower-fear clock everywhere inside
-- an 898 u ring. GH #558 measured what that buys and what it costs, and the two
-- answers point at different parts of the same ring.
--
-- THE PRIOR LEVER. mode_retreat_generic.X.ShouldRun, "前期谨慎冲塔" block, crude
-- clause: `( botLevel <= 5 or DotaTime() < nFearClock ) and nEnemyTowers[1] ~= nil
-- then return 2`, where the return becomes BOT_MODE_DESIRE_ABSOLUTE * 1.1 in
-- GetDesireHelper and outbids every other mode. Shipped nFearClock is 5*60;
-- armed `towerfear` halves it to 150, which releases levels 6-10 in the
-- 150-300 s window -- exactly the levels the disjunction's OTHER leg has already
-- released, because turbo doubles xp. See tests/test_towerfear_clock_leg.lua.
--
-- WHAT W50 SAID (replay group, 248 R_lever episodes over 65 games, GH #558):
--   * the first half of condition (a) is BOUGHT. In the rectangle the lever
--     releases: occ% +2.45, dwell +1.41 s, bounce% -23.88, every one of the
--     three same-signed in BOTH strata (铁律 4(i-a)/4(i-b)), against a
--     level-only control on which all three are sign-split noise.
--   * the second half came back with the WRONG SIGN. The share of released
--     episodes that touch the tower's own 700 u attack circle went +12.46 pp
--     (ab) / +35.21 pp (ba) -- both strata again. Episode-level is the reading:
--     the frame-weighted version is 70% one game (铁律 4(ii)).
--   * the named case: a sniper walks to 179 u, eats five seconds of tower fire,
--     504 -> 280 hp, nearest enemy hero >1000 u the whole time. Not a fight. The
--     shipped clock would have pulled him out.
--
-- THE LEVER (one). `towerring` keeps the halved clock where a tower cannot
-- reach and restores the shipped clock where it can:
--
--     local nFearClock = 5 * 60
--     local nFearClockShipped = nFearClock
--     if (IsSoakCandidate('towerfear') or IsSoakCandidate('towerring'))
--         and IsModeTurbo() then nFearClock = nFearClock / 2 end
--     if IsSoakCandidate('towerring') and IsModeTurbo()
--         and nEnemyTowers[1] ~= nil
--         and GetUnitToUnitDistance(bot, nEnemyTowers[1]) < 700
--     then nFearClock = nFearClockShipped end
--
-- 700 is the tower's attack range. It is not invented here: the block's own
-- comment already reasons from it -- the calibrated clause below cannot fire in
-- the 700-898 u annulus because `GetAttackTarget() == bot` is impossible there,
-- and 72.7% of released frames sit in that annulus (W8+W9, GH #178). Inside
-- 700 u the calibrated clause is the ONLY catcher and it demands the shot
-- already be in flight. So the geometry splits the lever exactly where its own
-- safety net does.
--
-- SUBSET, BOTH WAYS. released(towerring) is a strict subset of
-- released(towerfear), which is a strict subset of what the shipped clause
-- releases. This return can only fire MORE often than armed `towerfear` and
-- never more often than shipped.
--
-- SINGLE-ARM READABLE, AND IT DOMINATES. Armed alone, `towerring` halves only in
-- the annulus -- a wave can read it without `towerfear` in the string. Armed
-- TOGETHER with `towerfear`, the restore runs after the halving and wins, so the
-- pair reads as the narrowed lever. Both are asserted below on all seven
-- bearing frames. This is deliberate: the pair is the configuration a promote
-- would ship, and the alternative (nesting the new id inside the old gate) is
-- GH #542 / GH #553 -- two ids on one path, neither separable.
--
-- ⭐ DOMAIN PRICE, paid before the fix was written and stated without rounding.
-- tests/_towerfear_sweep.lua over the fixture archive: 109 fixtures, 1012 live
-- hero frames, 32 with an enemy tower inside the 898 ring, 17 where the crude
-- clause is ASKED, 3 where it fires, and exactly ONE held by the clock leg
-- alone -- the `towerfear` pin frame, at 727 u. **727 is in the annulus**, so on
-- the corpus as frozen, `towerring`'s restriction domain is ZERO frames: the
-- one frame the prior lever releases, this one releases too.
-- That is a fact about the CORPUS, not about the lever. These fixtures were
-- frozen for other reasons and our batch games self-terminate before sieges, so
-- "standing inside a tower's attack circle in the 2:30-5:00 window" is
-- under-sampled here; GH #558's 248 episodes are the population reading, and
-- there 18/55 (ab) and 41/90 (ba) armed episodes touched it.
-- ⇒ Every RESTRICTION assertion below therefore moves DotaTime() into the
-- released window on a real frame and moves nothing else. Level, hero lists,
-- health and -- the operand this lever is about -- the tower's distance are the
-- frame's own. The idiom is not new here: the `towerfear` file already argues
-- from the pin frame with the clock wound back to 149.
--
-- ⭐ WHAT THIS CORPUS CANNOT PIN, stated so nobody quotes a tighter claim.
-- The 700 literal is bracketed BEHAVIOURALLY only by the two nearest usable
-- frames: 649.41 u (restricted) and 727.46 u (released). Any mutation moving
-- 700 to a value strictly inside (649.41, 727.46) is NOT caught by the frames
-- -- it is caught only by the source assertion below. The obvious closer
-- witness, a juggernaut at 701.99 u, is UNUSABLE and is asserted to be so: an
-- earlier branch of ShouldRun returns HIGH on that frame at every clock, so it
-- bids 0.75 in all four worlds and can witness nothing. Same for a luna at
-- 245.20 u. Both are asserted rather than quietly dropped, because a frame that
-- looks like a control and answers the same in every world is the shape that
-- gets mistaken for evidence.
--
-- LIMITS (do not launder these away).
--   * The corpus cannot say whether the tower would have killed anyone: tower
--     GetAttackDamage/GetAttackSpeed are not in the dump (pinned by
--     tests/test_fixture_nearby_structures.lua). This file asserts the DECISION.
--   * `GetAssignedLane()` reads 0 in the fixture world, so the mid override
--     (1100/980 rings) is exercised by nothing here. `towerring` does not touch
--     it; the 700 u test is on `nEnemyTowers[1]` whichever ring produced it.
--   * The auction is not re-litigated here -- test_towerfear_clock_leg.lua owns
--     that claim, and this lever moves the same return.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local RETREAT = 'bots/mode_retreat_generic.lua'
local EPS = 1e-9
local BID_EPS = 1e-6

-- The frames, with the operand this lever reads. Distances are asserted off the
-- frames themselves in the premises test; the numbers here are labels.
local F_PIN    = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'          -- 727.46 annulus
local F_WK     = 'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua'        -- 787.32 annulus
local F_EMBER  = 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua'        -- 845.08 annulus
local F_POKED  = 'tests/fixtures/f_260820_043120_viper_defend_poked.lua'       -- 174.28 / 328.01 circle
local F_FLEE   = 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua'       -- 285.08 circle
local F_JUGGTP = 'tests/fixtures/f_260819_222030_jugg_tp_eaten.lua'            -- 649.41 circle (boundary)
local F_LVL4   = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua'       -- level leg holds
local F_BLINK  = 'tests/fixtures/f_260820_042612_axe_blink_init_573.lua'       -- 701.99, pre-empted
local F_DRAIN  = 'tests/fixtures/f_260820_182906_lion_drain_survived.lua'      -- 245.20, pre-empted

-- The window `towerfear` releases and `towerring` re-closes inside 700 u. 250 is
-- an arbitrary interior point; the boundary itself is owned by the towerfear
-- file, which pins 149.9/150.0/150.1 on the pin frame.
local IN_WINDOW = 250

-- The mock resolves unknown ALL_CAPS globals to sentinel integers, which makes a
-- desire comparison a comparison of garbage (test_set.md SS F).
local DESIRE = {
    BOT_MODE_DESIRE_NONE     = 0.0,
    BOT_MODE_DESIRE_VERYLOW  = 0.1,
    BOT_MODE_DESIRE_LOW      = 0.25,
    BOT_MODE_DESIRE_MODERATE = 0.5,
    BOT_MODE_DESIRE_HIGH     = 0.75,
    BOT_MODE_DESIRE_VERYHIGH = 0.9,
    BOT_MODE_DESIRE_ABSOLUTE = 1.0,
}
local FIRED = 1.1  -- BOT_MODE_DESIRE_ABSOLUTE * 1.1, the crude clause's return

--- opts.armed is a SET of ids. A set, not a single id: the whole domination
--- claim is about what happens when two of them are armed at once, and an
--- `armed = true, id = 'x'` stub cannot express that.
local function world(path, hero, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(path, hero)
    for k, v in pairs(DESIRE) do _G[k] = v end
    local armed = opts.armed or {}
    J.IsSoakCandidate = function(id) return armed[id] == true end
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
    -- GH #61: the loader refuses GetLaneFrontLocation; drivers still need one.
    GetLaneFrontLocation = function() return Vector(0, 0, 0) end -- luacheck: ignore
    -- GH #91: an UNSET defendPings stamp is not "no ping", it is "pinged this
    -- instant", which silences farm and all three push modes.
    rf.declare_defend_ping(J, 'stale')
    return J, bot, heroes, fx
end

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

--- All four worlds on one frame: shipped, `towerfear` alone, `towerring` alone,
--- and the pair. Everything below reads this, so no assertion can accidentally
--- compare two different frames.
local function quad(path, hero, now)
    local o = (now ~= nil) and { now = now } or {}
    local function w(set)
        local t = { now = o.now }
        t.armed = set
        return retreat_bid(path, hero, t)
    end
    return {
        shipped = w(nil),
        fear    = w({ towerfear = true }),
        ring    = w({ towerring = true }),
        both    = w({ towerfear = true, towerring = true }),
    }
end

local function tower_dist(path, hero, now)
    local _, bot = world(path, hero, (now ~= nil) and { now = now } or {})
    local tw = bot:GetNearbyTowers(898, true)
    assert(#tw >= 1, 'no enemy tower inside the 898 ring on ' .. path .. ' / ' .. hero)
    return GetUnitToUnitDistance(bot, tw[1]), bot:GetLevel(), #tw
end

-- ---------------------------------------------------------------------------
-- The source. Every constant the argument uses is read out of bots/ (0SRC/0CST).
-- ---------------------------------------------------------------------------

local SRC = (function()
    local fh = assert(io.open(RETREAT, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local BLOCK, BLOCK_AT = (function()
    local at = assert(SRC:find('前期谨慎冲塔', 1, true),
        'the 前期谨慎冲塔 block lost its comment anchor')
    -- End-anchored, not a byte window. A byte window measures PROSE: 3400 died
    -- to the GH #178 rewrite, 4800 died to this file's own rationale.
    local to = SRC:find('nEnemyTowers%[1%]:GetAttackTarget%(%) == bot', at)
    assert(to ~= nil,
        'no calibrated clause after the 前期谨慎冲塔 anchor -- the block was cut')
    return SRC:sub(at, to + 400), at
end)()

tests['source: the restore is turbo-gated on towerring, strict <, and reads the NEAREST tower'] = function()
    local gate = BLOCK:match(
        "if%s+J%.IsSoakCandidate%('([%w_]+)'%)%s+and%s+J%.IsModeTurbo%(%)%s*\n"
        .. "%s*and%s+nEnemyTowers%[1%]%s*~=%s*nil%s*\n"
        .. "%s*and%s+GetUnitToUnitDistance%(%s*bot,%s*nEnemyTowers%[1%]%s*%)%s*<%s*(%d+)")
    assert(gate ~= nil,
        'the restore clause is no longer "IsSoakCandidate(id) and IsModeTurbo() '
        .. 'and nEnemyTowers[1] ~= nil and GetUnitToUnitDistance(...) < N"')
    assert(gate == 'towerring', 'the restore is gated on ' .. tostring(gate) .. ', not towerring')

    local _, range = BLOCK:match(
        "if%s+J%.IsSoakCandidate%('([%w_]+)'%)%s+and%s+J%.IsModeTurbo%(%)%s*\n"
        .. "%s*and%s+nEnemyTowers%[1%]%s*~=%s*nil%s*\n"
        .. "%s*and%s+GetUnitToUnitDistance%(%s*bot,%s*nEnemyTowers%[1%]%s*%)%s*<%s*(%d+)")
    assert(tonumber(range) == 700,
        'the attack-circle radius is no longer 700 -- it is ' .. tostring(range)
        .. '. This is the tower attack range the block comment already reasons '
        .. 'from; a different number is a different lever and needs its own case.')

    -- The strict `<` matters: at exactly 700 the tower CAN reach, so 700 belongs
    -- to the annulus side only if the comparison stays strict. A `<=` moves the
    -- boundary and no fixture straddles it closely enough to notice (see the
    -- domain-price note above), which is why it is asserted textually.
    assert(BLOCK:find('nEnemyTowers%[1%]%s*%)%s*<%s*700') ~= nil,
        'the distance comparison is no longer a STRICT < against 700')
end

tests['source: the restore runs AFTER the halving -- that ordering IS the domination claim'] = function()
    local halve = BLOCK:find('nFearClock%s*=%s*nFearClock%s*/%s*2')
    local restore = BLOCK:find('nFearClock%s*=%s*nFearClockShipped')
    assert(halve ~= nil, 'the halving assignment is gone')
    assert(restore ~= nil, 'the restore assignment is gone -- towerring is unwired')
    assert(restore > halve,
        'the restore now runs BEFORE the halving, so arming both ids leaves the '
        .. 'halved clock everywhere and towerring silently becomes a no-op on '
        .. 'the pair -- which is the configuration a promote would ship')
end

tests['source: the shipped clock is captured once, so the two copies cannot drift'] = function()
    local shipped = BLOCK:match('local nFearClock%s*=%s*(%d+)%s*%*%s*60')
    assert(tonumber(shipped) == 5, 'the shipped clock leg is no longer 5 * 60')
    assert(BLOCK:match('local nFearClockShipped%s*=%s*nFearClock') ~= nil,
        'the shipped clock is no longer captured into nFearClockShipped -- if the '
        .. 'restore writes its own literal, the two can drift apart silently')
    -- Exactly two mentions: the binding and the restore. A third is a rewrite.
    local n = 0
    for _ in BLOCK:gmatch('nFearClockShipped') do n = n + 1 end
    assert(n == 2, 'nFearClockShipped occurs ' .. n .. ' times in the block, expected 2')
end

tests['source: the annulus this lever preserves is non-empty -- 700 < the block ring'] = function()
    -- If someone narrows ShouldRun's own tower ring below 700, `towerring`
    -- becomes "restore the shipped clock always", i.e. a no-op gate that still
    -- passes every behavioural assertion on frames that no longer exist.
    local ring = SRC:match('function X%.ShouldRun%(%).-local nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)')
    assert(ring ~= nil, 'ShouldRun no longer reads a literal near tower ring')
    assert(tonumber(ring) == 898, 'ShouldRun near ring moved to ' .. ring .. '; re-derive the annulus')
    assert(tonumber(ring) > 700,
        'the block ring is no longer wider than the tower attack range, so the '
        .. '700-898 annulus this lever preserves is empty and the id is a no-op')
    assert(BLOCK_AT > 0)
end

tests['source: the level leg is untouched -- this is one lever, not two'] = function()
    assert(BLOCK:match('botLevel%s*<=%s*5%s*or') ~= nil,
        'the level leg is no longer a bare `botLevel <= 5`')
    assert(BLOCK:match('or%s*DotaTime%(%)%s*<%s*nFearClock') ~= nil,
        'the clock leg no longer compares DotaTime() against nFearClock')
    -- towerring appears exactly twice in the block: the halving disjunct and the
    -- restore gate. A third site means it grew a second job.
    local n = 0
    for _ in BLOCK:gmatch("IsSoakCandidate%('towerring'%)") do n = n + 1 end
    assert(n == 2, "towerring is gated at " .. n .. " sites in this block, expected 2")
end

-- ---------------------------------------------------------------------------
-- Premises of the bearing frames, asserted off the frames.
-- ---------------------------------------------------------------------------

tests['REAL FRAMES: the seven bearing frames straddle the 700 attack circle'] = function()
    local rows = {
        { F_PIN,    'npc_dota_hero_zuus',               nil,       727.46, 7,  'annulus' },
        { F_WK,     'npc_dota_hero_skeleton_king',      IN_WINDOW, 787.32, 8,  'annulus' },
        { F_EMBER,  'npc_dota_hero_ember_spirit',       IN_WINDOW, 845.08, 7,  'annulus' },
        { F_POKED,  'npc_dota_hero_spirit_breaker',     IN_WINDOW, 174.28, 7,  'circle'  },
        { F_POKED,  'npc_dota_hero_lion',               IN_WINDOW, 328.01, 6,  'circle'  },
        { F_FLEE,   'npc_dota_hero_axe',                IN_WINDOW, 285.08, 10, 'circle'  },
        { F_JUGGTP, 'npc_dota_hero_obsidian_destroyer', IN_WINDOW, 649.41, 7,  'circle'  },
    }
    for _, r in ipairs(rows) do
        local path, hero, now, want_d, want_lvl, side = r[1], r[2], r[3], r[4], r[5], r[6]
        local d, lvl = tower_dist(path, hero, now)
        assert(math.abs(d - want_d) < 0.01,
            hero .. ' on ' .. path .. ': tower at ' .. string.format('%.2f', d)
            .. ', expected ' .. want_d)
        assert(lvl == want_lvl, hero .. ' is level ' .. lvl .. ', expected ' .. want_lvl)
        -- past the level leg, so the CLOCK leg is the only thing that can hold
        -- the frame -- which is what makes it a witness for this lever at all
        assert(lvl > 5, hero .. ' is level ' .. lvl .. ' -- the level leg holds it, '
            .. 'so nothing about the clock can be read here')
        assert(lvl <= 10, hero .. ' is past the outer level bound')
        if side == 'circle' then
            assert(d < 700, hero .. ' at ' .. d .. ' is not inside the attack circle')
        else
            assert(d > 700, hero .. ' at ' .. d .. ' is not in the annulus')
        end
        local J = world(path, hero, (now ~= nil) and { now = now } or {})
        assert(J.IsModeTurbo(), path .. ' is not a turbo dump -- the gate is turbo-only')
    end
end

tests['REAL FRAME: the annulus bearing frame needs NO clock manipulation at all'] = function()
    -- The one frame in the whole 1012-frame corpus that the clock leg alone
    -- holds. It is at 727 u, i.e. in the annulus, which is why the restriction
    -- assertions below have to move the clock and this one does not.
    local J, bot, _, fx = world(F_PIN, 'npc_dota_hero_zuus')
    assert(math.abs(fx.time - 278.5) < EPS, 'pinned at t=278.5, its own frame time')
    assert(bot:GetLevel() == 7, 'level 7 -- past the level leg')
    assert(fx.time >= 150 and fx.time < 300,
        'and inside the window the halving releases, at the frame own clock')
    assert(#J.GetEnemyList(bot, 1600) == 0 and bot:GetHealth() < 800,
        'the outer gate is carried by the health leg here, as towerfear records')
end

-- ---------------------------------------------------------------------------
-- Behaviour: the annulus is preserved.
-- ---------------------------------------------------------------------------

tests['ANNULUS (no manipulation): towerring releases the pin frame exactly as towerfear does'] = function()
    local q = quad(F_PIN, 'npc_dota_hero_zuus')
    assert(math.abs(q.shipped - FIRED) < BID_EPS,
        'shipped must bid ABSOLUTE*1.1 on the pin frame; got ' .. q.shipped)
    assert(math.abs(q.ring - q.fear) < BID_EPS,
        'at 727 u the tower cannot reach: towerring must be byte-identical to '
        .. 'towerfear. got ring=' .. q.ring .. ' fear=' .. q.fear)
    assert(math.abs(q.ring - (-0.36159216360228)) < BID_EPS,
        'the released bid moved; re-read the frame before quoting it. got ' .. q.ring)
    assert(q.ring < q.shipped - 0.5, 'and it is a release, not a rounding difference')
end

tests['ANNULUS: 787 u and 845 u are released by towerring, same as towerfear'] = function()
    for _, r in ipairs({ { F_WK, 'npc_dota_hero_skeleton_king' },
                         { F_EMBER, 'npc_dota_hero_ember_spirit' } }) do
        local q = quad(r[1], r[2], IN_WINDOW)
        assert(math.abs(q.shipped - FIRED) < BID_EPS,
            r[2] .. ': shipped must fire in the window; got ' .. q.shipped)
        assert(math.abs(q.ring - q.fear) < BID_EPS,
            r[2] .. ': in the annulus towerring must equal towerfear; got ring='
            .. q.ring .. ' fear=' .. q.fear)
        assert(q.ring < q.shipped - 0.5, r[2] .. ': towerring must release here')
    end
end

-- ---------------------------------------------------------------------------
-- Behaviour: the attack circle is re-closed. This is the whole point.
-- ---------------------------------------------------------------------------

tests['CIRCLE: towerring restores the shipped retreat where towerfear released'] = function()
    local rows = {
        { F_POKED,  'npc_dota_hero_spirit_breaker',     174.28 },
        { F_FLEE,   'npc_dota_hero_axe',                285.08 },
        { F_POKED,  'npc_dota_hero_lion',               328.01 },
        { F_JUGGTP, 'npc_dota_hero_obsidian_destroyer', 649.41 },
    }
    for _, r in ipairs(rows) do
        local q = quad(r[1], r[2], IN_WINDOW)
        local tag = r[2] .. ' @' .. r[3] .. 'u'
        assert(math.abs(q.shipped - FIRED) < BID_EPS,
            tag .. ': shipped must fire; got ' .. q.shipped)
        assert(q.fear < q.shipped - 0.5,
            tag .. ': towerfear must RELEASE this frame -- if it does not, this '
            .. 'frame witnesses nothing about narrowing it. got ' .. q.fear)
        assert(math.abs(q.ring - q.shipped) < BID_EPS,
            tag .. ': towerring must restore the shipped retreat; got ' .. q.ring)
    end
end

tests['CIRCLE: level 10 is covered, and that is the gap the calibrated clause has'] = function()
    -- The axe frame is level 10. The calibrated clause's own bound is
    -- `botLevel <= 9`, so a level-10 released frame has NO catcher at all -- the
    -- block comment measures that at 0.9% of released frames. towerring covers
    -- it by geometry rather than by level, which is why it does not need the
    -- calibrated clause's bound moved.
    local calib = BLOCK:match('botLevel%s*<=%s*(%d+)%s*\n%s*and%s*nEnemyTowers')
    assert(tonumber(calib) == 9, 'the calibrated clause bound moved to ' .. tostring(calib))
    local _, lvl = tower_dist(F_FLEE, 'npc_dota_hero_axe', IN_WINDOW)
    assert(lvl == 10 and lvl > tonumber(calib),
        'the axe frame is no longer past the calibrated bound, so this file no '
        .. 'longer covers the uncatchable band')
    local q = quad(F_FLEE, 'npc_dota_hero_axe', IN_WINDOW)
    assert(math.abs(q.ring - q.shipped) < BID_EPS,
        'towerring must hold the level-10 frame inside the circle; got ' .. q.ring)
end

tests['BOUNDARY: 649.41 u holds and 727.46 u releases -- and that bracket is all the frames buy'] = function()
    local d_in  = tower_dist(F_JUGGTP, 'npc_dota_hero_obsidian_destroyer', IN_WINDOW)
    local d_out = tower_dist(F_PIN, 'npc_dota_hero_zuus')
    assert(d_in < 700 and d_out > 700, 'the bracket no longer straddles 700')
    local q_in  = quad(F_JUGGTP, 'npc_dota_hero_obsidian_destroyer', IN_WINDOW)
    local q_out = quad(F_PIN, 'npc_dota_hero_zuus')
    assert(math.abs(q_in.ring - q_in.shipped) < BID_EPS, 'the inside frame must hold')
    assert(math.abs(q_out.ring - q_out.fear) < BID_EPS, 'the outside frame must release')
    -- and the honest width of what that proves
    assert(d_out - d_in > 70 and d_out - d_in < 90,
        'the behavioural bracket is (' .. string.format('%.2f, %.2f', d_in, d_out)
        .. '); if it narrowed, update the domain-price note at the top rather '
        .. 'than leaving a stale claim about what the frames cannot pin')
end

tests['NON-WITNESSES: two frames near 700 answer the same in all four worlds, at every clock'] = function()
    -- 701.99 u is the closest frame to the boundary in the corpus and it is
    -- USELESS: an earlier ShouldRun branch bids HIGH regardless. Asserted, not
    -- dropped -- if a future edit makes either of them move, they become the
    -- tight boundary witnesses this file says it does not have.
    for _, r in ipairs({ { F_BLINK, 'npc_dota_hero_juggernaut', 701.99 },
                         { F_DRAIN, 'npc_dota_hero_luna', 245.20 } }) do
        local d = tower_dist(r[1], r[2], IN_WINDOW)
        assert(math.abs(d - r[3]) < 0.01, r[2] .. ' moved to ' .. d)
        for _, now in ipairs({ 160, 200, 250, 290, 299 }) do
            local q = quad(r[1], r[2], now)
            assert(math.abs(q.shipped - 0.75) < BID_EPS,
                r[2] .. ' at t=' .. now .. ' no longer bids HIGH from an earlier '
                .. 'branch (' .. q.shipped .. ') -- it may now be a usable witness')
            assert(math.abs(q.fear - q.shipped) < BID_EPS
                and math.abs(q.ring - q.shipped) < BID_EPS
                and math.abs(q.both - q.shipped) < BID_EPS,
                r[2] .. ' at t=' .. now .. ' now distinguishes the worlds')
        end
    end
end

-- ---------------------------------------------------------------------------
-- Domination, subset, and the [reverse] half.
-- ---------------------------------------------------------------------------

local ALL_SEVEN = {
    { F_PIN,    'npc_dota_hero_zuus',               nil },
    { F_WK,     'npc_dota_hero_skeleton_king',      IN_WINDOW },
    { F_EMBER,  'npc_dota_hero_ember_spirit',       IN_WINDOW },
    { F_POKED,  'npc_dota_hero_spirit_breaker',     IN_WINDOW },
    { F_POKED,  'npc_dota_hero_lion',               IN_WINDOW },
    { F_FLEE,   'npc_dota_hero_axe',                IN_WINDOW },
    { F_JUGGTP, 'npc_dota_hero_obsidian_destroyer', IN_WINDOW },
}

tests['DOMINATION: arming both ids equals arming towerring alone, on every bearing frame'] = function()
    for _, r in ipairs(ALL_SEVEN) do
        local q = quad(r[1], r[2], r[3])
        assert(math.abs(q.both - q.ring) < BID_EPS,
            r[2] .. ': the pair must read as the NARROWED lever, not as towerfear. '
            .. 'got both=' .. q.both .. ' ring=' .. q.ring .. ' fear=' .. q.fear)
    end
end

tests['SUBSET: released(towerring) is contained in released(towerfear), strictly'] = function()
    local differ = 0
    for _, r in ipairs(ALL_SEVEN) do
        local q = quad(r[1], r[2], r[3])
        -- On every frame, towerring's answer is either towerfear's or shipped's.
        -- A third value would mean this lever computes something of its own.
        local same_as_fear = math.abs(q.ring - q.fear) < BID_EPS
        local same_as_ship = math.abs(q.ring - q.shipped) < BID_EPS
        assert(same_as_fear or same_as_ship,
            r[2] .. ': towerring produced a THIRD bid (' .. q.ring .. ') that is '
            .. 'neither shipped (' .. q.shipped .. ') nor towerfear (' .. q.fear .. ')')
        if not same_as_fear then
            differ = differ + 1
            assert(math.abs(q.shipped - FIRED) < BID_EPS,
                r[2] .. ': towerring differs from towerfear on a frame where the '
                .. 'clause does not even fire -- that cannot be this lever')
        end
    end
    assert(differ == 4,
        'towerring must differ from towerfear on exactly the 4 circle frames; got '
        .. differ .. '. Fewer means the restriction stopped biting.')
end

tests['[reverse] the level leg still closes the mechanism: level 4 is identical in all worlds'] = function()
    local q = quad(F_LVL4, 'npc_dota_hero_lina', IN_WINDOW)
    local _, lvl = tower_dist(F_LVL4, 'npc_dota_hero_lina', IN_WINDOW)
    assert(lvl == 4, 'the control frame is no longer level 4; got ' .. lvl)
    for _, k in ipairs({ 'fear', 'ring', 'both' }) do
        assert(math.abs(q[k] - q.shipped) < BID_EPS,
            'level 4 is held by the LEVEL leg, so ' .. k .. ' must be a no-op there; got '
            .. q[k] .. ' against shipped ' .. q.shipped)
    end
    assert(math.abs(q.shipped - FIRED) < BID_EPS, 'and the clause does fire there')
end

tests['[reverse] the gate is turbo-only: in normal mode towerring changes nothing'] = function()
    for _, r in ipairs({ { F_JUGGTP, 'npc_dota_hero_obsidian_destroyer' },
                         { F_PIN, 'npc_dota_hero_zuus' } }) do
        local now = (r[1] == F_PIN) and nil or IN_WINDOW
        local shipped = retreat_bid(r[1], r[2], { now = now })
        local normal_ring = retreat_bid(r[1], r[2],
            { now = now, armed = { towerring = true }, normal_mode = true })
        local normal_pair = retreat_bid(r[1], r[2],
            { now = now, armed = { towerring = true, towerfear = true }, normal_mode = true })
        assert(math.abs(normal_ring - shipped) < BID_EPS,
            r[2] .. ': armed towerring in NORMAL mode must be the shipped world; got '
            .. normal_ring)
        assert(math.abs(normal_pair - shipped) < BID_EPS,
            r[2] .. ': the pair in NORMAL mode must be the shipped world too; got '
            .. normal_pair)
    end
end

tests['[reverse] arming a DIFFERENT id changes nothing -- the gate reads its own name'] = function()
    for _, r in ipairs(ALL_SEVEN) do
        local shipped = retreat_bid(r[1], r[2], { now = r[3] })
        local other = retreat_bid(r[1], r[2],
            { now = r[3], armed = { towerrings = true, towerfea = true, tower = true } })
        assert(math.abs(other - shipped) < BID_EPS,
            r[2] .. ': arming near-miss ids moved the bid to ' .. other
            .. ' -- the gate is matching something other than its own id')
    end
end

return tests
