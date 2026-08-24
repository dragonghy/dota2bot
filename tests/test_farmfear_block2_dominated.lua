-- The "前期谨慎冲塔" block in mode_farm_generic.X.ShouldRun is written TWICE,
-- back to back -- and the second copy cannot decide anything the first has not
-- already decided.
--
-- THE TWO BLOCKS (bots/mode_farm_generic.lua, inside X.ShouldRun):
--
--   -- BLOCK 1: long ring 1200 (mid 1100), near ring 898 (mid 980), latch 2
--   if botLevel <= 10 and DotaTime() > 0 and (#enemies > 0 or hp < 700) then
--       if ( botLevel <= 2 or DotaTime() < 2*60 ) and nLongEnemyTowers[1] then return 2 end
--       if ( botLevel <= 4 or DotaTime() < 3*60 ) and nEnemyTowers[1]     then return 2 end
--       if botLevel <= 9 and nEnemyTowers[1] ... :GetAttackTarget() == bot
--           and #allies <= 1                                             then return 2 end
--   end
--   -- BLOCK 2: long ring 999 (mid 988), near ring 898 (mid 966), latch 1
--   if botLevel <= 10          and (#enemies > 0 or hp < 700) then
--       ... the same three clauses, byte-identical legs ...
--   end
--
-- THE ARITHMETIC. Every ring in block 2 is INSIDE the matching ring in block 1
-- (999 < 1200, 988 < 1100, 966 < 980; off mid neither block re-locals the near
-- ring, so both read ShouldRun's own 898). The level legs, the clock legs and
-- the calibrated clause are byte-identical. So each block-2 clause IMPLIES the
-- matching block-1 clause -- and block 1 runs first and RETURNS. The only
-- asymmetry anywhere in the two blocks is block 1's extra `DotaTime() > 0`.
-- Therefore block 2 can decide something only while `DotaTime() <= 0`, i.e.
-- before the horn -- where its own outer gate additionally demands an enemy
-- hero within 1600 or the bot below 700 HP.
--
-- WHY THIS IS WORTH PINNING RATHER THAN JUST DELETING. The conclusion is not
-- "these lines are ugly", it is an ARITHMETIC RELATION between eight constants
-- in two places. Any future edit that raises a block-2 ring, lowers a block-1
-- ring, or splits a leg makes ~28 lines of `return 1` come alive silently --
-- with a DIFFERENT latch (1s instead of 2s) feeding the same
-- BOT_MODE_DESIRE_ABSOLUTE * 1.1 in GetDesireHelper. Writing the relation as a
-- test is the charter's 0WRAP rule (assert the fact, do not describe it in a
-- comment) applied to a dominance claim: the day someone changes a constant,
-- this file goes red and tells them the dead code is no longer dead.
--
-- SCOPE, stated so nobody reads more into it. This file asserts DOMINANCE, not
-- desirability. It does NOT claim block 1's constants are right (they are the
-- subject of the clock-constant axis, GH #157), and it does NOT delete
-- anything: a deletion is a behaviour change in the pre-horn corner and belongs
-- in a gated fix with its own evidence.
--
-- WHAT THE CORPUS SAYS (tests/_farmfear_sweep.lua, 104 fixtures / 966 live hero
-- frames, ~37s, zero AWS -- run on demand, NOT from this file, because the
-- suite already does not finish in a routine container, GH #124):
--   * block 1's outer gate open      549 / 966;  block 2's, identically 549
--   * block 2's gate open while block 1's is shut:            0
--   * a block-2 ring holding a tower block 1's ring missed:   0 (long AND near)
--   * the long clause asked 33 times, fires 0; the near clause asked 16, fires
--     1 -- and that one is held by the LEVEL leg (a level-4 Lina at t=201.3)
--   * so the whole block decides 1 of 966 frames, and block 2 decides none.
--
-- AND THE MID OVERRIDES CANNOT BE CHECKED ON FRAMES AT ALL. `GetAssignedLane`
-- is not in the mock, so it falls through to the `^Get` default 0 while every
-- unknown ALL_CAPS global resolves to a distinct id >= 1001: on 966/966 live
-- frames the value equals NO LANE_* constant (already declared for the pull
-- census, tests/test_pullcamp_trigger_census.lua note (4), and for the retreat
-- copy in tests/test_towerfear_clock_leg.lua). Both mid branches are therefore
-- unreachable locally, and the mid half of the dominance claim rests on the
-- SOURCE arithmetic below -- which is why that arithmetic is asserted rather
-- than sampled. Both directions of that reading are pinned below.

-- DEFENCE-PING DECLARATION (GH #91). This file asserts NO mode bid: it reads
-- the two blocks out of the source and evaluates them as a pure model, and the
-- only engine values it touches are the frame's level, clock, hero lists and
-- tower distances. So the `defendPings` stamp -- which an undeclared fixture
-- world sets to "pinged this instant", silencing mode_farm_generic and the
-- three push modes for 5s -- cannot reach any claim made here. Declared rather
-- than assumed, because the day this file grows a GetDesire() reading it must
-- take it out of a `stale` world (a defence ping is an event, not a condition),
-- and the ratchet in tests/test_defend_ping_declaration_ratchet.lua is what
-- will remind whoever adds it.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local FARM = 'bots/mode_farm_generic.lua'

-- The frame this file drives: a level-7 Zeus 727u from an enemy tower that is
-- NOT shooting him (the [towerfear] pin frame, reused deliberately -- it is the
-- one frame in the corpus that puts a tower inside BOTH blocks' long rings, so
-- block 2 is asked on populated data and still adds nothing).
local F_PIN = 'tests/fixtures/f_260819_142047_zuus_ult_denied.lua'
local PIN_HERO = 'npc_dota_hero_zuus'
-- and the one frame where block 1 actually fires, held by its level leg.
local F_FIRES = 'tests/fixtures/f_260819_122930_lich_rescue_doomed.lua'
local FIRES_HERO = 'npc_dota_hero_lina'

-- ---------------------------------------------------------------------------
-- Read every constant out of the shipped source (charter 0SRC).
-- ---------------------------------------------------------------------------

local SRC = (function()
    local fh = assert(io.open(FARM, 'r'))
    local s = fh:read('*a'); fh:close()
    return s
end)()

local SHOULDRUN = (function()
    local at = assert(SRC:find('function X.ShouldRun(bot)', 1, true),
        'X.ShouldRun moved or was renamed in ' .. FARM)
    return SRC:sub(at, at + 9000)
end)()

local WINDOW = (function()
    local at = assert(SHOULDRUN:find('前期谨慎冲塔', 1, true),
        'the 前期谨慎冲塔 comment anchor is gone from X.ShouldRun')
    local w = SHOULDRUN:sub(at, at + 2600)
    -- Self-witnessing window (charter 0LN2): if it no longer reaches the second
    -- copy's calibrated clause, fail with THAT, not with "the clause is gone".
    local _, n = w:gsub('GetAttackTarget%(%) == bot', '')
    assert(n == 2, ('the source window from 前期谨慎冲塔 reaches %d calibrated '
        .. 'clause(s), not 2 -- widen it; the blocks may be intact'):format(n))
    return w
end)()

local function num(v, msg) assert(v ~= nil, msg); return tonumber(v) end

-- ShouldRun's own near ring, the one both blocks read off mid.
local NEAR_RING = num(SHOULDRUN:match('local nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
    'X.ShouldRun no longer reads a literal near tower ring')
local HERO_RING = num(SHOULDRUN:match('local hEnemyHeroList%s*=%s*J%.GetEnemyList%(bot,(%d+)%)'),
    'X.ShouldRun no longer builds hEnemyHeroList over a literal radius')

local B1, B2 = (function()
    local starts = {}
    for at in WINDOW:gmatch('()botLevel <= 10') do starts[#starts + 1] = at end
    assert(#starts == 2, ('expected exactly 2 `botLevel <= 10` outer gates in '
        .. 'the 前期谨慎冲塔 window, found %d -- the two-copy shape this file is '
        .. 'about has changed'):format(#starts))
    return WINDOW:sub(starts[1], starts[2] - 1), WINDOW:sub(starts[2])
end)()

--- Every constant of one copy, read out of that copy's own text.
local function legs(part, what)
    local mid = assert(part:match('LANE_MID(.-)\n%s*end'),
        what .. ': the mid override branch is gone or no longer ends with `end`')
    local L = {
        outer_hp = num(part:match('bot:GetHealth%(%)%s*<%s*(%d+)'),
            what .. ': the outer gate lost its literal GetHealth() floor'),
        -- the mid override must be read out of the MID BRANCH: the
        -- `local nLongEnemyTowers = ...` line above it matches the same pattern
        -- and a copy-wide match hands back the off-mid ring instead (0SRC).
        ring_long = num(part:match('local nLongEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
            what .. ': the copy no longer opens with a literal long tower ring'),
        ring_mid_long = num(mid:match('nLongEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
            what .. ': the mid override no longer re-reads a literal long ring'),
        ring_mid_near = num(mid:match('nEnemyTowers%s*=%s*bot:GetNearbyTowers%((%d+),%s*true%)'),
            what .. ': the mid override no longer re-reads a literal near ring'),
        calib_level = num(part:match('botLevel%s*<=%s*(%d+)%s*\n%s*and nEnemyTowers'),
            what .. ': the calibrated clause lost its literal level bound'),
        pre_horn = part:match('DotaTime%(%)%s*>%s*0') ~= nil,
    }
    local lvl_long, clk_long = part:match(
        'botLevel%s*<=%s*(%d+)%s*or%s*DotaTime%(%)%s*<%s*([^%)]-)%s*%)%s*\n%s*and nLongEnemyTowers')
    local lvl_near, clk_near = part:match(
        'botLevel%s*<=%s*(%d+)%s*or%s*DotaTime%(%)%s*<%s*([^%)]-)%s*%)%s*\n%s*and nEnemyTowers')
    assert(lvl_long and lvl_near, what .. ': the two crude clauses no longer read '
        .. '"botLevel <= N or DotaTime() < X" over the long / near tower list')
    local function clock(expr, tag)
        local n = expr:match('^(%d+)%s*%*%s*60$')
        if n ~= nil then return tonumber(n) * 60 end
        assert(expr:match('^[%w_]+$'), ('%s: the %s clock bound `%s` is neither a '
            .. 'literal `N * 60` nor a bare local name'):format(what, tag, expr))
        local d = part:match('local ' .. expr .. '%s*=%s*(%d+)%s*%*%s*60')
            or SHOULDRUN:match('local ' .. expr .. '%s*=%s*(%d+)%s*%*%s*60')
        assert(d ~= nil, ('%s: the %s clock bound is the local `%s` and no '
            .. '`local %s = N * 60` default was found'):format(what, tag, expr, expr))
        return tonumber(d) * 60
    end
    L.lvl_long, L.clk_long = tonumber(lvl_long), clock(clk_long, 'long')
    L.lvl_near, L.clk_near = tonumber(lvl_near), clock(clk_near, 'near')
    L.ring_near = NEAR_RING
    return L
end

local L1, L2 = legs(B1, 'block1'), legs(B2, 'block2')

-- ---------------------------------------------------------------------------
-- 1. The relation itself.
-- ---------------------------------------------------------------------------

tests['the two copies still exist and only block 1 guards the horn'] = function()
    assert(L1.pre_horn, 'block 1 lost its `DotaTime() > 0` outer guard -- the '
        .. 'whole dominance conclusion is about that guard being the ONLY '
        .. 'asymmetry; re-derive before trusting anything below')
    assert(not L2.pre_horn, 'block 2 GREW a `DotaTime() > 0` guard -- it is now '
        .. 'dead in every direction, which is a DIFFERENT (stronger) claim than '
        .. 'this file makes; update the file')
    assert(L1.outer_hp == L2.outer_hp, ('the two outer gates now use different '
        .. 'HP floors (%d vs %d) -- block 2 can outlive block 1 on HP alone')
        :format(L1.outer_hp, L2.outer_hp))
end

tests['every block-2 ring is inside the matching block-1 ring'] = function()
    assert(L2.ring_long < L1.ring_long, ('block 2 long ring %d is not inside '
        .. 'block 1 long ring %d'):format(L2.ring_long, L1.ring_long))
    assert(L2.ring_mid_long < L1.ring_mid_long, ('block 2 mid long ring %d is '
        .. 'not inside block 1 mid long ring %d'):format(L2.ring_mid_long, L1.ring_mid_long))
    assert(L2.ring_mid_near < L1.ring_mid_near, ('block 2 mid near ring %d is '
        .. 'not inside block 1 mid near ring %d'):format(L2.ring_mid_near, L1.ring_mid_near))
    -- off mid neither block re-locals the near ring: they read the SAME list.
    assert(L1.ring_near == NEAR_RING and L2.ring_near == NEAR_RING,
        'a copy started re-localing the off-mid near ring; the off-mid half of '
        .. 'the dominance claim no longer follows from identity')
end

tests['the level, clock and calibrated legs are identical between the copies'] = function()
    assert(L1.lvl_long == L2.lvl_long and L1.clk_long == L2.clk_long,
        ('the long clause legs diverged: block1 (%d, %ds) vs block2 (%d, %ds)')
        :format(L1.lvl_long, L1.clk_long, L2.lvl_long, L2.clk_long))
    assert(L1.lvl_near == L2.lvl_near and L1.clk_near == L2.clk_near,
        ('the near clause legs diverged: block1 (%d, %ds) vs block2 (%d, %ds)')
        :format(L1.lvl_near, L1.clk_near, L2.lvl_near, L2.clk_near))
    assert(L1.calib_level == L2.calib_level,
        ('the calibrated level bounds diverged: %d vs %d')
        :format(L1.calib_level, L2.calib_level))
end

-- ---------------------------------------------------------------------------
-- 2. The conclusion, executed rather than argued: over a grid that straddles
--    every boundary either copy names, block 2 never decides while the horn has
--    blown. A pure model of the two blocks -- no engine, no fixtures -- so it
--    covers mid, which no fixture can (see the header).
-- ---------------------------------------------------------------------------

local function evaluate(L, t, lvl, dist, bMid, nEnemies, hp, bAttacked, nAllies, bHorn)
    if not (lvl <= 10 and (not L.pre_horn or bHorn) and (nEnemies > 0 or hp < L.outer_hp)) then
        return nil
    end
    local rLong = bMid and L.ring_mid_long or L.ring_long
    local rNear = bMid and L.ring_mid_near or L.ring_near
    if (lvl <= L.lvl_long or t < L.clk_long) and dist <= rLong then return 'long' end
    if (lvl <= L.lvl_near or t < L.clk_near) and dist <= rNear then return 'near' end
    if lvl <= L.calib_level and dist <= rNear and bAttacked and nAllies <= 1 then
        return 'calibrated'
    end
    return nil
end

tests['grid: after the horn, block 2 never decides anything block 1 left open'] = function()
    local TS = { -30, -0.1, 0, 0.1, 59, 60, 61, 119, 120, 121, 179, 180, 181, 300, 600 }
    local DS = { 0, 700, 897, 898, 899, 965, 966, 967, 979, 980, 981, 987, 988, 989,
                 998, 999, 1000, 1099, 1100, 1101, 1199, 1200, 1201, 2000 }
    local checked, b2Live = 0, 0
    for _, t in ipairs(TS) do
        for lvl = 1, 12 do
            for _, dist in ipairs(DS) do
                for _, bMid in ipairs({ false, true }) do
                    for _, nEnemies in ipairs({ 0, 1 }) do
                        for _, hp in ipairs({ 500, 900 }) do
                            for _, bAttacked in ipairs({ false, true }) do
                                for _, nAllies in ipairs({ 1, 2 }) do
                                    local bHorn = t > 0
                                    checked = checked + 1
                                    local r1 = evaluate(L1, t, lvl, dist, bMid,
                                        nEnemies, hp, bAttacked, nAllies, bHorn)
                                    if r1 == nil then
                                        local r2 = evaluate(L2, t, lvl, dist, bMid,
                                            nEnemies, hp, bAttacked, nAllies, bHorn)
                                        if r2 ~= nil then
                                            b2Live = b2Live + 1
                                            assert(not bHorn, ('block 2 decided (%s) '
                                                .. 'AFTER the horn where block 1 did '
                                                .. 'not: t=%s lvl=%d dist=%d mid=%s '
                                                .. 'enemies=%d hp=%d attacked=%s '
                                                .. 'allies=%d -- the dead-code '
                                                .. 'conclusion is void, re-derive it')
                                                :format(r2, tostring(t), lvl, dist,
                                                tostring(bMid), nEnemies, hp,
                                                tostring(bAttacked), nAllies))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    assert(checked > 100000, 'the grid shrank below the boundaries it must '
        .. 'straddle; got ' .. checked)
    -- and the pre-horn corner is REAL, not an empty escape hatch: if it were
    -- empty the claim would be "dead everywhere", which is a different claim.
    assert(b2Live > 0, 'block 2 is now unreachable even before the horn -- that '
        .. 'is a STRONGER statement than this file makes; update the header '
        .. 'before relying on it')
end

tests['grid: the domination is not vacuous -- block 1 does fire on this grid'] = function()
    local fires = 0
    for _, t in ipairs({ 60, 200, 600 }) do
        for lvl = 1, 12 do
            for _, dist in ipairs({ 700, 950, 1150 }) do
                if evaluate(L1, t, lvl, dist, false, 1, 900, false, 1, true) ~= nil then
                    fires = fires + 1
                end
            end
        end
    end
    assert(fires > 0, 'block 1 fires nowhere on the grid -- the grid, not the '
        .. 'code, is what this test would then be measuring')
end

-- ---------------------------------------------------------------------------
-- 3. Real frames. The engine values come from the replay; nothing is invented.
-- ---------------------------------------------------------------------------

local function frame(path, hero)
    local J, bot = rf.load(path, hero)
    J.IsSoakCandidate = function() return false end
    local t, lvl = DotaTime(), bot:GetLevel()
    local nLane = bot:GetAssignedLane()
    local bMid = (nLane == LANE_MID)
    local tEnemies = J.GetEnemyList(bot, HERO_RING) or {}
    local tAllies = J.GetAllyList(bot, HERO_RING) or {}
    local function nearest(r)
        local tw = bot:GetNearbyTowers(r, true) or {}
        if tw[1] == nil then return nil end
        return GetUnitToUnitDistance(bot, tw[1]), tw[1]
    end
    return {
        J = J, bot = bot, t = t, lvl = lvl, nLane = nLane, bMid = bMid,
        enemies = #tEnemies, allies = #tAllies, hp = bot:GetHealth(),
        nearest = nearest,
    }
end

tests['world assertion: GetAssignedLane matches no LANE_* constant, both directions'] = function()
    for _, f in ipairs({ { F_PIN, PIN_HERO }, { F_FIRES, FIRES_HERO } }) do
        local fr = frame(f[1], f[2])
        assert(fr.nLane == 0, ('%s: GetAssignedLane no longer reads the mock '
            .. '`^Get` default 0 (got %s) -- if the loader learned the method, '
            .. 'the mid branches became testable and the header must say so')
            :format(f[1], tostring(fr.nLane)))
        assert(fr.nLane ~= LANE_MID and fr.nLane ~= LANE_TOP and fr.nLane ~= LANE_BOT,
            f[1] .. ': the mock default now collides with a LANE_* constant, so '
            .. 'every `== LANE_*` branch silently picks one lane')
    end
end

tests['pin frame: a tower inside BOTH long rings, and block 2 still adds nothing'] = function()
    local fr = frame(F_PIN, PIN_HERO)
    -- the frame is not vacuous: the tower is inside block 2's long ring too.
    local d = fr.nearest(L2.ring_long)
    assert(d ~= nil, 'the pin frame no longer has an enemy tower inside block 2 '
        .. "long ring " .. L2.ring_long .. ' -- pick another witness frame')
    assert(d < L1.ring_long, 'and inside block 1 long ring')
    -- both copies are ASKED (outer gate open) ...
    local bAttacked = false
    local _, hT = fr.nearest(L1.ring_near)
    if hT ~= nil then bAttacked = hT:CanBeSeen() and hT:GetAttackTarget() == fr.bot end
    local r1 = evaluate(L1, fr.t, fr.lvl, d, fr.bMid, fr.enemies, fr.hp,
        bAttacked, fr.allies, fr.t > 0)
    local r2 = evaluate(L2, fr.t, fr.lvl, d, fr.bMid, fr.enemies, fr.hp,
        bAttacked, fr.allies, fr.t > 0)
    -- ... and neither fires: level 7 is past both level legs and t is past both
    -- clock legs, so the frame falls through to the calibrated clause, which is
    -- false because the tower is not shooting this bot.
    assert(fr.lvl > L1.lvl_near and fr.t >= L1.clk_near,
        ('the pin frame moved off the band it was chosen for (lvl=%d t=%.1f)')
        :format(fr.lvl, fr.t))
    assert(r1 == nil, 'block 1 now fires on the pin frame: ' .. tostring(r1))
    assert(r2 == nil, 'block 2 now fires on the pin frame: ' .. tostring(r2))
end

tests['firing frame: block 1 decides, and its LEVEL leg is what holds it'] = function()
    local fr = frame(F_FIRES, FIRES_HERO)
    local d = fr.nearest(L1.ring_near)
    assert(d ~= nil, 'the firing frame no longer has a tower in the near ring')
    local r1 = evaluate(L1, fr.t, fr.lvl, d, fr.bMid, fr.enemies, fr.hp,
        false, fr.allies, fr.t > 0)
    assert(r1 == 'near', 'block 1 no longer decides via its near clause here; '
        .. 'got ' .. tostring(r1))
    -- which leg holds it -- the distinction the whole clock-constant axis
    -- (GH #157) turns on, so it is asserted in BOTH directions.
    assert(fr.lvl <= L1.lvl_near, ('the level leg no longer holds this frame '
        .. '(lvl=%d bound=%d)'):format(fr.lvl, L1.lvl_near))
    assert(fr.t >= L1.clk_near, ('the clock leg now ALSO holds this frame '
        .. '(t=%.1f bound=%d) -- it is no longer a level-leg control')
        :format(fr.t, L1.clk_near))
    -- and block 2 is never even reached, because block 1 returned.
    local r2 = evaluate(L2, fr.t, fr.lvl, d, fr.bMid, fr.enemies, fr.hp,
        false, fr.allies, fr.t > 0)
    assert(r2 == 'near', 'block 2 would have decided differently from block 1 '
        .. 'on the one frame the block fires; got ' .. tostring(r2))
end

return tests
