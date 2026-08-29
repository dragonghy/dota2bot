-- [detector] The two ZERO_TRUE sites, driven -- and what the fix did NOT fix.
--
-- THE BATON.  `tests/test_incoming_damage_callsite_census.lua` (hero, 2026-08-29)
-- enumerated the 41 call expressions that read `GetActualIncomingDamage` and
-- found the mock's old zero had TWO polarities, not one.  32 sites put the call
-- where a zero makes the predicate FALSE (the half already written up); **2 put
-- it on the small side of a `<`, where a zero makes the predicate TRUE**:
--
--   mode_retreat_generic.lua       X.RetreatWhenTowerTargetedDesire()
--                                  `nDamage / botTarget:GetHealth() < 0.88`
--   ability_item_usage_generic.lua X.ConsiderItemDesire.item_metamorphic_mandible
--                                  `GetActualIncomingDamage(...) < bot:GetHealth()`
--
-- Those two are the fix's ONLY green->red direction, and the census classed them
-- by READING the enclosing expression -- it drove neither.  Its own closing line
-- said so: "whoever wants to use an assertion on these two paths, drive one
-- first" (charter `iterations/streams/hero.md` -45).  This file is that drive.
--
-- WHAT THE DRIVE FINDS.  Two things, and the second is the one worth carrying.
--
--   1. THE READING WAS RIGHT.  §2 and §5 reinstate the legacy zero on the frame's
--      own units and both branches fire unconditionally; with the fixed default
--      and enough damage on the other side of the comparison, both decline.  The
--      polarity is now proven rather than read.
--
--   2. ⭐ THE FIX DID NOT MAKE EITHER SITE CONDITIONAL ON A FIXTURE FRAME.  Each
--      one has a SECOND unmodelled zero UPSTREAM of the call, and it belongs to
--      the mock/loader rather than to the frame, so it survived the fix intact:
--
--        retreat  -- the subject's own `GetEstimatedDamageToTarget` is 0 on every
--                    fixture.  The loader has ground truth for damage enemies
--                    dealt TO the subject (`observed.burst`) and none at all for
--                    damage the subject would deal OUT, so it hands every hero
--                    the burst-against-the-subject reader and the subject's own
--                    is 0.  `nDamage` is therefore 0 BEFORE
--                    GetActualIncomingDamage is ever called.
--        mandible -- every enemy's `GetAttackDamage()` and `GetAttackSpeed()` are
--                    0 (a .dem slice carries neither), so the `dmg * speed *
--                    duration` sum is 0 before the call.
--
--      So the baton's worry -- "a green that asserts *the retreat desire is 0.9
--      on this frame* may be reading the mock" -- is STILL TRUE after the fix.
--      Only the mock datum handing out the green changed.  §3 and §6 pin that:
--      they assert 0.9 / DESIRE_HIGH **with the fixed default in place**, and say
--      in the assertion message that the value is upstream-given, not earned.
--      Anyone citing these paths must supply the upstream datum explicitly, the
--      way §2 and §5 do.
--
-- REACHABILITY, since it bounds who can ever cite site A: the guard needs a live
-- ENEMY tower within 800u, DotaTime <= 600, a live hero target, attack-ish mode
-- and no team fight.  §1 walks the whole fixture corpus for the two clauses a
-- frame can actually carry (tower distance, clock) and finds the domain is TWO
-- frames wide -- both focus heroes, which is why this stream owns the baton.
--
-- ANNOTATIONS (declared, not smuggled -- the dumper emits none of these, GH #27).
--   * `GetActiveMode` / `GetAttackTarget` / `GetTarget` on the subject.  Without
--     them J.IsGoingOnSomeone is false and J.GetProperTarget is nil, and neither
--     branch is reachable on any frame at all.
--   * the mandible's `duration` special value (KV data, never in a .dem).  The
--     assertions below are POLARITY at two damage regimes, not magnitude, but
--     the regimes are computed from the declared duration -- read them together.
--   * the outgoing damage estimate in §2, which is exactly the missing datum
--     finding 2 is about.
--
-- LIMITS.  Reinstating the zero via `__spec` models "this unit takes no damage",
-- which is what the old default said; it does not re-run the old mock. And
-- "no reduction modelled" stays the fixed default's own upper bound (heroes have
-- 25% base magic resistance in game), so a branch that declines here declines at
-- least as hard in a real match, and one that fires may not.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local rf  = require('mock.replay_fixture')

local tests = {}

-- The two corpus frames that sit inside site A's domain. Named rather than
-- discovered so a corpus change renames them in one place.
local AXE_FRAME = 'tests/fixtures/f_260820_043124_axe_blink_flee_529.lua'
local WK_FRAME  = 'tests/fixtures/f_260820_102030_wk_tower_in_reach.lua'
-- Site B needs recent hero damage and enemies in 1600 instead; this is the
-- textbook shape (a support at 30% deciding whether it survives the commit).
local CM_FRAME  = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'

local TOWER_RADIUS = 800   -- bot:GetNearbyTowers(800, true) in the guard
local CLOCK        = 600   -- DotaTime() > 10 * 60 returns 0

local function fixture_paths()
    local out = {}
    local p = io.popen('ls tests/fixtures/f_*.lua')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    table.sort(out)
    return out
end

--- The two domain clauses a fixture can actually answer from its own bytes.
--- Mode and target are annotations (see header), so they are not asked here.
local function in_site_a_domain(fx)
    local subj
    for _, u in ipairs(fx.units or {}) do
        if u.name == fx.self then subj = u end
    end
    if not (subj and subj.alive) then return false end
    if not (fx.time and fx.time <= CLOCK) then return false end
    for _, b in ipairs(fx.buildings or {}) do
        if b.name == 'tower' and b.alive and b.team ~= subj.team then
            local d = math.sqrt((b.x - subj.x) ^ 2 + (b.y - subj.y) ^ 2)
            if d <= TOWER_RADIUS then return true end
        end
    end
    return false
end

--- Load a frame and hand back (J, bot, heroes) with the mode/target annotation
--- applied and the chosen enemy target returned alongside.
local function load_with_target(path)
    local J, bot, heroes = rf.load(path)
    local target
    for name, h in pairs(heroes) do
        if name:find('^npc_dota_hero') and h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            if target == nil or h:GetHealth() < target:GetHealth() then target = h end
        end
    end
    assert(target, 'no live enemy hero on ' .. path)
    local sp = rawget(bot, '__spec')
    sp.GetAttackTarget = function() return target end
    sp.GetTarget       = function() return target end
    sp.GetActiveMode   = function() return BOT_MODE_ATTACK end
    return J, bot, heroes, target
end

--- Load mode_retreat_generic against an installed frame and run the module's own
--- setter, so `botTarget` is filled by the shipped code path (GetDesireHelper's
--- `botTarget = J.GetProperTarget(bot)`) rather than poked in from outside.
local function drive_retreat(J, bot)
    local X = require(GetScriptDirectory() .. '/mode_retreat_generic')
    assert(J.IsGoingOnSomeone(bot), 'the mode annotation did not take')
    assert(not J.IsPushing(bot), 'attack mode must not read as pushing')
    assert(not J.IsInTeamFight(bot, 1600),
        'this frame has 2+ allies in attack mode, so the guard returns 0 early')
    assert(#bot:GetNearbyTowers(TOWER_RADIUS, true) >= 1,
        'no enemy tower within ' .. TOWER_RADIUS .. ' -- the frame left the domain')
    GetDesireHelper()   -- the shipped setter for the file-local botTarget
    return X
end

tests['[detector] site A is reachable on exactly the frames this file names'] = function()
    local hits = {}
    for _, path in ipairs(fixture_paths()) do
        local ok, fx = pcall(dofile, path)
        if ok and type(fx) == 'table' and in_site_a_domain(fx) then hits[path] = true end
    end
    -- Existence claims, plus a LOWER bound. Not an equality: a compliant new
    -- fixture that happens to stand under an enemy tower would then turn trunk
    -- red for growing, which is GH #273's exact shape.
    assert(hits[AXE_FRAME], AXE_FRAME .. ' is no longer inside site A\'s domain '
        .. '(live enemy tower within ' .. TOWER_RADIUS .. 'u, DotaTime <= ' .. CLOCK .. ')')
    assert(hits[WK_FRAME], WK_FRAME .. ' is no longer inside site A\'s domain')
    local n = 0
    for _ in pairs(hits) do n = n + 1 end
    assert(n >= 2, 'the corpus no longer reaches site A at all (' .. n .. ' frames)')
    -- The neighbouring near-miss, recorded because it is the clock and not the
    -- geometry that excludes it: earthshaker stands 212u from an enemy tower at
    -- t=621, past the guard's `DotaTime() > 10 * 60` return.
    local es = 'tests/fixtures/f_260820_163429_es_blink_init_621.lua'
    local ok, fx = pcall(dofile, es)
    if ok and type(fx) == 'table' then
        assert(not hits[es], es .. ' entered the domain -- if its clock moved, the '
            .. 'note in this test about why it is excluded is now wrong')
        assert(fx.time > CLOCK, 'the near-miss is excluded by the clock, not the geometry')
    end
end

tests['[detector] site A driven: the census ZERO_TRUE reading is correct'] = function()
    local J, bot, _, target = load_with_target(AXE_FRAME)
    local X = drive_retreat(J, bot)

    -- The missing datum, declared. 800 over 5s against a 770hp skeleton king is
    -- above the guard's 0.88 bar once the 1.2 multiplier is applied
    -- (800 * 1.2 = 960; 960 / 770 = 1.25), i.e. "I can finish him, do not run".
    local hp = target:GetHealth()
    local est = math.ceil(hp * 0.88 / 1.2) + 100
    rawget(bot, '__spec').GetEstimatedDamageToTarget = function() return est end
    assert(X.RetreatWhenTowerTargetedDesire() == 0,
        'with a real outgoing estimate the guard must NOT bid to retreat: the bot '
        .. 'can finish the target it is diving')

    -- Now reinstate the world the old default described -- "no damage of any type
    -- reaches this unit" -- on the target only, through the same __spec door a
    -- test would use to model real armour.
    rawget(target, '__spec').GetActualIncomingDamage = function() return 0 end
    assert(X.RetreatWhenTowerTargetedDesire() == 0.9,
        'under the legacy zero the same frame bids 0.9 -- this is the ZERO_TRUE '
        .. 'polarity the census read and never drove')
    rawget(target, '__spec').GetActualIncomingDamage = nil

    -- And the branch is genuinely conditional, not merely inverted: an estimate
    -- that really is short of the bar bids 0.9 with the FIXED default too.
    local short = math.floor(hp * 0.88 / 1.2) - 100
    rawget(bot, '__spec').GetEstimatedDamageToTarget = function() return short end
    assert(X.RetreatWhenTowerTargetedDesire() == 0.9,
        'a genuinely insufficient estimate must still bid to retreat')
end

tests['[detector] site A: the fix did NOT make it conditional on a fixture frame'] = function()
    -- The finding this file exists to carry. No annotation beyond mode/target,
    -- the FIXED default in place, and the guard still fires unconditionally --
    -- because a second unmodelled zero sits upstream of the call.
    for _, path in ipairs({ AXE_FRAME, WK_FRAME }) do
        local J, bot, _, target = load_with_target(path)
        local X = drive_retreat(J, bot)
        assert(bot:GetEstimatedDamageToTarget(true, target, 5.0, DAMAGE_TYPE_ALL) == 0,
            'the subject now HAS an outgoing damage estimate on ' .. path .. '. That '
            .. 'is good news and it expires this assertion: re-read every published '
            .. 'claim about this guard, they were made when the number was 0.')
        assert(X.RetreatWhenTowerTargetedDesire() == 0.9,
            path .. ': the guard bids 0.9 here, but NOT because the frame says to. '
            .. 'The subject\'s outgoing estimate is 0, so `nDamage` is 0 before '
            .. 'GetActualIncomingDamage is reached. Do not cite this 0.9 as a frame '
            .. 'observation -- supply the estimate first, as the driven test does.')
    end
end

tests['[detector] site B driven: the mandible desire has the same polarity'] = function()
    local J, bot = rf.load(CM_FRAME)
    rawget(bot, '__spec').GetActiveMode = function() return BOT_MODE_ATTACK end
    assert(J.IsGoingOnSomeone(bot), 'the mode annotation did not take')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0),
        'the consider needs recent hero damage; this frame stopped carrying it')

    local X = require(GetScriptDirectory() .. '/ability_item_usage_generic')
    local consider = X and X.ConsiderItemDesire and X.ConsiderItemDesire['item_metamorphic_mandible']
    assert(type(consider) == 'function', 'the mandible consider is gone or renamed')

    local nDuration = 3  -- declared annotation: KV data, no fixture carries it
    local item = api.MakeAbility('item_metamorphic_mandible', { GetSpecialValueInt = nDuration })

    -- Who the consider will actually count: it needs the enemy pointed at us.
    local near = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    local counted = {}
    for _, e in ipairs(near) do
        if bot:WasRecentlyDamagedByHero(e, 3.0) then counted[#counted + 1] = e end
    end
    assert(#counted >= 1, 'no enemy on this frame qualifies for the damage sum')

    -- The missing datum, declared: enough attack damage that the sum (x1.5)
    -- exceeds the subject's health, i.e. "I do not survive this, do not commit".
    local function arm(dmg)
        for _, e in ipairs(near) do
            local sp = rawget(e, '__spec')
            sp.GetAttackDamage, sp.GetAttackSpeed = dmg, 1.0
        end
    end
    local lethal = math.ceil(bot:GetHealth() / (1.5 * nDuration * #counted)) + 20
    arm(lethal)
    assert(consider(item) == BOT_ACTION_DESIRE_NONE,
        'with a real incoming estimate the mandible must decline: the subject does '
        .. 'not live through the window it would be committing to')

    rawget(bot, '__spec').GetActualIncomingDamage = function() return 0 end
    assert(consider(item) == BOT_ACTION_DESIRE_HIGH,
        'under the legacy zero the same frame wants it -- ZERO_TRUE, driven')
    rawget(bot, '__spec').GetActualIncomingDamage = nil

    local survivable = math.floor(bot:GetHealth() / (1.5 * nDuration * #near)) - 5
    assert(survivable >= 1, 'pick a frame with more health headroom')
    arm(survivable)
    assert(consider(item) == BOT_ACTION_DESIRE_HIGH,
        'and it still fires when the subject really does live through the window')
end

tests['[detector] site B: the fix did NOT make it conditional either'] = function()
    local J, bot = rf.load(CM_FRAME)
    rawget(bot, '__spec').GetActiveMode = function() return BOT_MODE_ATTACK end
    local X = require(GetScriptDirectory() .. '/ability_item_usage_generic')
    local consider = X.ConsiderItemDesire['item_metamorphic_mandible']
    local item = api.MakeAbility('item_metamorphic_mandible', { GetSpecialValueInt = 3 })

    local near = bot:GetNearbyHeroes(1600, true, BOT_MODE_NONE)
    assert(#near >= 1, 'the frame lost its nearby enemies')
    for _, e in ipairs(near) do
        assert(e:GetAttackDamage() == 0 and e:GetAttackSpeed() == 0,
            'an enemy now HAS attack damage/speed on this frame. Good news, and it '
            .. 'expires this assertion: re-read anything published about this desire.')
    end
    assert(consider(item) == BOT_ACTION_DESIRE_HIGH,
        'the desire is HIGH here with the FIXED default in place -- and not because '
        .. 'the frame says so: every enemy\'s attack damage is 0, so the sum is 0 '
        .. 'before GetActualIncomingDamage is reached. Same shape as site A.')
end

tests['[detector] the two upstream zeros are the loader\'s, and are still undeclared'] = function()
    -- Why finding 2 is a property of the harness rather than of these frames, and
    -- where it would have to be fixed. Both are the same class as the zero this
    -- whole baton chain is about: a mock default stating a world assumption
    -- nobody wrote down.
    local loader = assert(io.open('tests/mock/replay_fixture.lua')):read('*a')
    assert(loader:find('GetEstimatedDamageToTarget = function() return burst end', 1, true),
        'the loader stopped handing every hero the burst-against-the-subject '
        .. 'reader -- if it now models outgoing damage, sections 3 and 6 are stale')
    local mock = assert(io.open('tests/mock/bot_api.lua')):read('*a')
    for _, key in ipairs({ 'GetAttackDamage', 'GetAttackSpeed' }) do
        assert(not mock:find("key == '" .. key .. "'", 1, true),
            key .. ' now has an explicit default. The mandible site may have become '
            .. 'conditional on real frames; re-drive it before citing section 6.')
    end
end

return tests
