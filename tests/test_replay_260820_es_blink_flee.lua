-- [blinkflee / GH #74 §1.5(3), director 21:15Z §10.1] The blinkflee frame pair
-- on a SECOND hero and a SECOND wave -- and the ground truth that splits it.
--
-- Context. GH #71 pinned `blinkflee` on one game and one hero: Axe burned a
-- 15s CD dagger twice as a retreat "leg" at 84% / 81% HP with no hero
-- pressure. The honest boundary written into that round was "the evidence is
-- two frames of one Axe in one game". Replay-check's 20:49Z pre-flight
-- (GH #74) then re-photographed the same defect SHAPE on earthshaker across
-- two independent games of the 1609xx/1807xx waves, and the director ordered
-- this fixture pair as the zero-cost way to widen that boundary without
-- buying another wave.
--
-- The two real frames (both re-derived here from the .dem, not copied from
-- the issue -- the cast instants, the geometry and the damage book all
-- reproduce):
--
--   HOLD  f_260820_162859_es_blink_flee_615 -- cast at t=615.2, decided on the
--         last snapshot before it (t=614.9, the #66 §0 cast-frame rule).
--         ES 1528/1528 HP (100%), viper 1091 away (inside the branch's 1200),
--         zero hero damage in the lookback. Blink lands 1416u away and
--         -1412 closer to its own ancient => a retreat leg, not an initiation.
--
--   PASS  f_260820_163429_es_blink_init_621 -- cast at t=621.3, decided at
--         t=621.0. ES 1770/1770 HP, *zero* enemies within 1200, three allies
--         within 550. Blink lands +747 AWAY from its own ancient, into viper
--         420 / SK 548 => a textbook initiation.
--
-- What this file pins, and what it deliberately refuses to claim:
--
--   1. MECHANISM. On the HOLD frame the guard fires exactly as designed, and
--      stays inert with the gate closed or outside turbo.
--
--   2. THE INITIATION IS NOT PROTECTED BY THE GUARD. On the PASS frame
--      `J.ShouldHoldBlinkFlee` also returns true (100% HP, no hero damage) --
--      the guard cannot tell an initiation from a flight. What keeps the
--      offensive blink is the retreat branch's OWN precondition
--      (`#nInRangeEnemy >= 1`), which is false there, so armed and shipped are
--      bit-identical on that frame. Pinned as an assertion so nobody credits
--      the guard with a discrimination it does not perform.
--
--   3. [limitation] THE HOLD SET IS NOT HOMOGENEOUS -- the negative result of
--      this round. The guard reads the same three inputs the same way on all
--      three HOLD frames, but the ground truth splits them:
--
--        Axe t=529.6  84% HP  ->  burst {} over the next 5s, survived
--        Axe t=555.2  81% HP  ->  burst {} over the next 5s, survived
--        ES  t=614.9 100% HP  ->  viper 1175 over the next 5s, DIED at +6.0s
--
--      On the ES frame the fire started ~1.5s AFTER the decision and killed
--      the bot; a viper standing 1091 away that has simply not opened up yet
--      reads identically to no threat at all through a 2.0s LOOKBACK. So the
--      "cost of holding is zero" half of GH #71's argument (c) is true of the
--      two Axe frames and NOT established on this one -- and the blink did
--      not save it either (it blinked and still died), which is why this is a
--      caveat on the argument rather than a refutation of the gate.
--      n=3. Asserted from observed ground truth so the claim cannot quietly
--      drift back to "always free".

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local ES_FLEE = 'tests/fixtures/f_260820_162859_es_blink_flee_615.lua'
local ES_INIT = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua'
local AXE_529 = 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua'
local AXE_555 = 'tests/fixtures/f_260820_043124_axe_blink_flee_555.lua'

local tests = {}

--- Load a fixture with (turbo, gate) freely armed via the returned J.
local function load_fx(path, opts)
    opts = opts or {}
    local J, bot = rf.load(path)
    J.IsModeTurbo = function() return opts.turbo == true end
    J.IsSoakCandidate = function(id)
        return opts.armed == true and id == 'blinkflee'
    end
    return J, bot
end

--- Raw fixture table (for the observed/ground-truth reads).
local function raw(path)
    return dofile(path)
end

-- ---------------------------------------------------------------------------
-- 1. The HOLD frame: earthshaker, game 20260820_162859, t=614.9.

tests['ES t=614.9: the frame really is a retreat leg (branch domain)'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = true, armed = true })
    assert(math.abs(bot:GetHealth() / bot:GetMaxHealth() - 1.0) < 0.001,
        'ES is at full HP on this frame (1528/1528)')
    -- The retreat branch only reaches the guard when at least one enemy is
    -- inside 1200 -- viper at 1091 is what puts this frame in the domain.
    local near = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)
    assert(near ~= nil and #near == 1,
        'exactly one enemy (viper) inside 1200 -- the branch precondition holds')
end

tests['ES t=614.9, gate OFF: the guard is inert'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = true, armed = false })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'gate not armed -> shipped behaviour, guard must be a no-op')
end

tests['ES t=614.9, non-turbo: the guard is inert'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = false, armed = true })
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'turbo-only gate, so a normal-mode game must see shipped behaviour')
end

tests['ES t=614.9, gate ON: full HP + no hero fire -> HOLD'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = true, armed = true })
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'no hero has touched ES in the lookback window on this frame')
    assert(J.ShouldHoldBlinkFlee(bot) == true,
        'the #71 defect shape reproduces on a second hero and a second wave')
end

tests['ES t=614.9, gate ON, mutate HP under 70%: guard releases'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = true, armed = true })
    rawget(bot, '__spec').GetHealth = math.floor(bot:GetMaxHealth() * 0.60 + 0.5)
    rawset(bot, 'GetHealth', nil)
    assert(bot:GetHealth() / bot:GetMaxHealth() < 0.70, 'sanity: 60% < 70%')
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'below the HP floor the guard must let the retreat blink through')
end

tests['ES t=614.9, gate ON, mutate: recent hero damage releases the guard'] = function()
    local J, bot = load_fx(ES_FLEE, { turbo = true, armed = true })
    rawget(bot, '__spec').WasRecentlyDamagedByAnyHero = function(_, f)
        return (tonumber(f) or 0) >= 1.5
    end
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == true,
        'sanity: the mutation put a hero hit inside the 2.0s window')
    assert(J.ShouldHoldBlinkFlee(bot) == false,
        'a hero actively pressing ES makes the blink a legitimate escape')
end

-- ---------------------------------------------------------------------------
-- 2. The PASS frame: the offensive blink is NOT saved by the guard.

tests['ES t=621.0: zero enemies in 1200 -> the retreat leg is unreachable'] = function()
    local J, bot = load_fx(ES_INIT, { turbo = true, armed = true })
    local near = J.GetEnemiesNearLoc(bot:GetLocation(), 1200)
    assert(near ~= nil and #near == 0,
        'no enemy within 1200 on the initiation frame')
    -- => the retreat branch's `#nInRangeEnemy >= 1` clause is false, so the
    -- guard is never consulted and armed == shipped bit for bit here.
end

tests['ES t=621.0: [limitation] the guard alone would NOT spare the initiation'] = function()
    local J, bot = load_fx(ES_INIT, { turbo = true, armed = true })
    assert(math.abs(bot:GetHealth() / bot:GetMaxHealth() - 1.0) < 0.001,
        'ES is at full HP')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0) == false,
        'and only a creep chipped it 4.4s ago')
    -- Both of the guard's clauses pass, so it would hold this blink too if the
    -- branch ever reached it. The offensive blink survives because of the
    -- branch precondition asserted above, NOT because the guard is smart.
    assert(J.ShouldHoldBlinkFlee(bot) == true,
        'the guard cannot distinguish an initiation from a flight')
end

tests['ES t=621.0: the cast is geometrically an initiation, not a leg'] = function()
    local fx = raw(ES_INIT)
    -- Ground truth from the replay: it blinked +747 AWAY from its own ancient
    -- and landed on viper 420 / SK 548, both of whom then damaged it.
    assert(fx.observed.burst['npc_dota_hero_viper'] ~= nil,
        'viper is in contact right after the blink -- it jumped INTO them')
    assert(fx.observed.burst['npc_dota_hero_skeleton_king'] ~= nil,
        'and so is skeleton_king')
end

-- ---------------------------------------------------------------------------
-- 3. [limitation] The negative result: the HOLD set is not homogeneous.

tests['[limitation] identical guard reading, opposite ground truth (n=3)'] = function()
    local frames = {
        { path = AXE_529, name = 'axe t=529.6' },
        { path = AXE_555, name = 'axe t=555.2' },
        { path = ES_FLEE, name = 'es  t=614.9' },
    }
    local died, survived = {}, {}
    for _, fr in ipairs(frames) do
        local J, bot = load_fx(fr.path, { turbo = true, armed = true })
        -- Every one of the three reads HOLD through the same three clauses.
        assert(J.ShouldHoldBlinkFlee(bot) == true,
            fr.name .. ': guard holds (that is the point -- the input is the same)')
        local fx = raw(fr.path)
        if fx.observed.died_after ~= nil then
            table.insert(died, fr.name)
        else
            table.insert(survived, fr.name)
        end
    end
    -- The outcomes are NOT the same. Two were free; one was lethal.
    assert(#survived == 2 and #died == 1,
        'the three HOLD frames split 2 survived / 1 died -- got '
        .. #survived .. '/' .. #died)
    local es = raw(ES_FLEE)
    assert(es.observed.died_after ~= nil and es.observed.died_after <= 8.0,
        'ES died within 8s of the frame the guard calls "not under pressure"')
    assert((es.observed.burst['npc_dota_hero_viper'] or 0) > 1000,
        'viper put >1000 damage into it in the 5s after that frame')
    -- And the fire had not started yet at decision time -- which is exactly why
    -- a 2.0s LOOKBACK cannot see it.
    assert(es.observed.damage[1] ~= nil and es.observed.damage[1].t > 1.0,
        'the first hero hit lands AFTER the decision instant, not before it')
end

tests['[limitation] neither ES frame is illusion-contaminated (GH #69)'] = function()
    -- The ground-truth claims above are only admissible if the combat log had
    -- no name/entity ambiguity on these frames; the generator withholds
    -- burst/died_after and sets these flags when it cannot tell them apart.
    for _, p in ipairs({ ES_FLEE, ES_INIT }) do
        local fx = raw(p)
        assert(fx.observed.ground_truth_ambiguous ~= true,
            p .. ': burst/died_after must be entity-clean to be cited')
        assert(fx.observed.recent_damage_ambiguous ~= true,
            p .. ': the lookback book must be entity-clean too')
    end
end

return tests
