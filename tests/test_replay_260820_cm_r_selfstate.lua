-- Replay-fixture regression for hero.md backlog #13: the Freezing Field gate
-- never asked anything about CRYSTAL MAIDEN HERSELF.
--
-- X.cm_IsRSafeToOpen was built (GH #34, GH #66) entirely out of facts about the
-- ENEMY: who holds a ready hard CC, and does he stand inside cast range + 400.
-- Every one of its inputs is about them. GH #66 section 2 frame A is the bill:
-- at 20260820_103216_slot1 t=473.5 Crystal Maiden was at 292/1110 (26%), was
-- carrying a modifier_stunned with 0.2s still to run from a hit 1.1s earlier,
-- had taken 919 points of hero damage in the preceding 6 seconds and had two
-- enemies inside 300 units with her nearest ally 1543 away. None of that is
-- addressable by the gate as written, it released, and she opened a ten-second
-- self-rooting channel: stunned again at 474.4, dead at 474.5 -- the fixture's
-- own ground truth, died_after = 1.0.
--
-- The new clause is gated turbo + 'cmrself' and is a CONJUNCTION of two facts
-- about her: below X.nRSelfHpFloor health AND under hero fire inside
-- X.nRSelfFireWindow seconds. Either half alone is ordinary (a support is often
-- low; being shot at is what a teamfight IS, and a teamfight is when the
-- ultimate is worth channelling), so the pair is the lever and both halves are
-- pinned here with their own witness frame:
--
--   A. tests/fixtures/f_260820_103216_cm_es_aftershock.lua -- t=473.5, BASELINE
--      side. 26.3% and hit 0.2s ago: BOTH halves true, must WITHHOLD.
--   B. tests/fixtures/f_260820_102645_cm_es_reach.lua -- t=391.5, ARMED side.
--      51.5% but ALSO under fire (Bristleback hit her 1.5s before the instant),
--      so the release here is attributable to the health floor alone and the
--      fire half is proven not to be carrying the verdict by itself. Ground
--      truth: she lived another 106.9 seconds. Must still RELEASE.
--
-- The two frames bracket the floor far from either edge -- any floor in
-- (0.264, 0.514] reproduces both verdicts, and 0.38 (the number ConsiderR's
-- retreat branch already uses) sits in the middle. A case below scans that band
-- and both frames just outside it.
--
-- SEPARATION FROM 'cmrguard' (the axeblink trap): the ring scan and this clause
-- are now two independently gated blocks under one shared turbo check. Arming
-- either id alone changes behaviour on its own -- asserted in both directions --
-- so neither id's batch arm is silently measuring the other. Arming 'cmrguard'
-- alone is byte-for-byte the pre-change gate, which is asserted BEHAVIOURALLY
-- (drop her to 1 hp under 'cmrguard' alone and nothing moves), not by reading
-- the source.
--
-- EXTERNAL ANCHORS (not in the dump -- make_fixture.py extracts no ability
-- specs, the caveat every gate test here carries):
--   * crystal_maiden_freezing_field: mana cost 200 at level 1, AoE radius 835.
--     Load bearing for the end-to-end cases only; at the mock default of 0 the
--     radius makes J.GetNearbyHeroes return nobody and every bid is an empty
--     green. The gate itself reads NEITHER of them.
--
-- ROLE HEAL (strategy backlog 0c, GH #57): BOTH fixtures now carry the drafted
-- roles -- frame B since 2026-08-21, frame A since 2026-08-22 -- so the
-- positions here are the draft, not the slot order the loader used to fall back
-- to. Every case in this file survived both heals unchanged, and the reason is
-- measured rather than assumed in test_replay_260820_cm_es_aftershock.lua: the
-- clause under test asks nothing about anyone's position, so the sniper and
-- skeleton_king core/support flips on frame A cannot reach it. Do not read that
-- as "role heals are safe here" for any future clause: the moment this gate
-- grows a J.IsCore fork, both frames have to be re-read.
package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CLOSE = 'tests/fixtures/f_260820_103216_cm_es_aftershock.lua' -- must BLOCK armed
local REACH = 'tests/fixtures/f_260820_102645_cm_es_reach.lua'      -- must RELEASE

local FIELD_RADIUS    = 835 -- external anchor, see header
local FIELD_MANA_COST = 200 -- external anchor (level 1)

--- Load a frame with an explicit set of armed candidate ids.
local function load_armed(path, tIds)
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id)
        for _, s in ipairs(tIds) do if s == id then return true end end
        return false
    end
    return J, bot, heroes, fx
end

--- Overwrite the subject's health. J.GetHP reads OriginalGet* for own-team
--- units, so both pairs have to move or the mutation is invisible to the gate.
local function set_hp(bot, nHp)
    local spec = rawget(bot, '__spec')
    spec.GetHealth, spec.OriginalGetHealth = nHp, nHp
end

--- Drive the REAL X.ConsiderR() on a frame with the ultimate's two specs
--- anchored. Returns the bid plus the loaded world.
local function bid_considerR(path, tIds, fTweak)
    local J, bot, heroes, fx = load_armed(path, tIds)
    local sAbilityList = J.Skill.GetAbilityList(bot)
    assert(sAbilityList[6] == 'crystal_maiden_freezing_field',
        'the ultimate must be reachable in the fixture world (GH #36)')
    local abilityR = bot:GetAbilityByName(sAbilityList[6])
    local spec = rawget(abilityR, '__spec')
    spec.GetAOERadius = FIELD_RADIUS
    spec.GetManaCost = FIELD_MANA_COST
    assert(abilityR:IsFullyCastable(),
        'R is trained, off cooldown and affordable on this real frame')
    if fTweak then fTweak(J, bot, heroes) end
    local X = rf.load_hero('crystal_maiden')
    return X.ConsiderR(), J, bot, heroes, fx
end

local function hero_source()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local s = f:read('*a')
    f:close()
    return s
end

local tests = {}

-- ------------------------------------------------------------- ground truth

tests['frame A ground truth: 26.3% hp, mid-stun, under fire, two enemies inside 300'] = function()
    local J, bot, heroes, fx = load_armed(CLOSE, {})
    assert(fx.self == 'npc_dota_hero_crystal_maiden')
    assert(fx.time == 473.5, 'the last snapshot strictly before the 474.3 cast')
    assert(bot:GetHealth() == 292 and bot:GetMaxHealth() == 1110, 'CM hp on the real frame')
    assert(math.abs(J.GetHP(bot) - 0.2631) < 0.0001, 'the fraction the floor is compared against')

    -- Under HERO fire, and specifically not creep chip: the clause reads
    -- WasRecentlyDamagedByAnyHero, and on this frame the two answers differ.
    assert(bot:WasRecentlyDamagedByAnyHero(2.0), 'hero damage landed 0.2s ago')
    assert(bot:WasRecentlyDamagedByCreep(2.0) == false,
        'no creep touched her -- the fire half is fed by heroes only here')
    -- What that fire actually amounted to, from the fixture's own history.
    local nHeroDamage = 0
    for _, u in ipairs(fx.units) do
        if u.name == fx.self then
            for _, d in ipairs(u.recent_damage or {}) do
                if d.kind == 'hero' then nHeroDamage = nHeroDamage + d.value end
            end
        end
    end
    assert(nHeroDamage == 919, '919 points of hero damage in the 6s lookback, against 292 hp')

    assert(bot:HasModifier('modifier_stunned'), 'she is still inside a stun on the decision frame')
    local n300 = 0
    for _, h in pairs(J.GetNearbyHeroes(bot, 1600, true, BOT_MODE_NONE)) do
        if GetUnitToUnitDistance(bot, h) <= 300 then n300 = n300 + 1 end
    end
    assert(n300 == 2, 'Earthshaker 195.9u and Zeus 268u are both on top of her')
    local nAllies = J.GetNearbyHeroes(bot, 1600, false, BOT_MODE_NONE)
    assert(#nAllies == 1
        and math.floor(GetUnitToUnitDistance(bot, nAllies[1])) == 1543,
        'her nearest ally is 1543u away -- nobody is covering the channel')
    assert(fx.observed.died_after == 1.0, 'she was dead 1.0s after this frame (ground truth)')
end

tests['frame B ground truth: 51.5% and ALSO under fire -- the fire half cannot carry it'] = function()
    local J, bot, _, fx = load_armed(REACH, {})
    assert(fx.time == 391.5)
    assert(bot:GetHealth() == 436 and bot:GetMaxHealth() == 847)
    assert(math.abs(J.GetHP(bot) - 0.5148) < 0.0001, 'well above the floor')
    assert(bot:WasRecentlyDamagedByAnyHero(2.0),
        'Bristleback hit her for 161 at dt=1.5 -- the fire half of the conjunction '
        .. 'is TRUE on this frame, so the release below is the health floor alone')
    assert(bot:HasModifier('modifier_stunned') == false, 'she is not in a stun here')
    assert(fx.observed.died_after == 106.9, 'she survived this one by 106.9s (ground truth)')
end

-- ----------------------------------------------------- the defect, then the fix

tests['frame A, nothing armed: shipped releases -- unchanged by this entry'] = function()
    local _, bot = load_armed(CLOSE, {})
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'off every candidate nothing may change')
end

tests['frame A, `cmrguard` armed ALONE: still releases -- the blind spot, stated positively'] = function()
    local J, bot, heroes = load_armed(CLOSE, { 'cmrguard' })
    -- Not because the ring is empty of enemies -- two stand inside it -- but
    -- because neither is holding a ready ability the curated table knows.
    assert(J.GetReadyHardCc(heroes['npc_dota_hero_earthshaker']) == nil
        and J.GetReadyHardCc(heroes['npc_dota_hero_zuus']) == nil,
        'the enemy-side gate finds nothing to veto on')
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'a 26%-hp CM in a stun with two enemies on her passes a gate that only '
        .. 'asks about THEM -- this is backlog #13 reproduced')
end

tests['frame A, `cmrself` armed ALONE: withheld'] = function()
    local _, bot = load_armed(CLOSE, { 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false,
        'below the health floor and under fire, the 10s channel must be withheld')
end

tests['frame A, `cmrguard` + `cmrself`: withheld (the union, no interference)'] = function()
    local _, bot = load_armed(CLOSE, { 'cmrguard', 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == false)
end

tests['frame A, non-turbo with `cmrself` armed: unchanged'] = function()
    local J, bot = load_armed(CLOSE, { 'cmrself' })
    J.IsModeTurbo = function() return false end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'the whole gate is turbo-only')
end

tests['frame B, `cmrself` armed: still releases, and the health floor is why'] = function()
    local J, bot = load_armed(REACH, { 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    assert(bot:WasRecentlyDamagedByAnyHero(X.nRSelfFireWindow),
        'the fire half is true here -- restated at the point of use')
    assert(J.GetHP(bot) >= X.nRSelfHpFloor, 'the health half is false here')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'a 51.5% CM under fire is an ordinary teamfight, not a thrown ultimate')
end

tests['frame B, `cmrguard` + `cmrself`: still releases'] = function()
    local _, bot = load_armed(REACH, { 'cmrguard', 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'the ES at 536.1u is outside the 400 ring (GH #66) and she is above the floor')
end

-- ------------------------------------------------- the two ids do not overlap

tests['`cmrguard` alone is blind to her own state: 1 hp changes nothing'] = function()
    local _, bot = load_armed(CLOSE, { 'cmrguard' })
    local X = rf.load_hero('crystal_maiden')
    set_hp(bot, 1)
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'with only the enemy-side id armed the new clause must be inert -- this is '
        .. 'the behavioural statement of "arming cmrguard alone is unchanged"')
end

tests['`cmrself` alone is blind to the enemy table: same world, two ids, opposite answers'] = function()
    -- One mutated world, built on frame A and labelled: (i) her health lifted to
    -- 60% so the self clause is FALSE, (ii) Earthshaker's fissure -- the one
    -- curated ability the shipped scan knows -- handed back off cooldown, at his
    -- real 195.9u, inside the 0 + 400 ring. Whichever id is armed decides.
    local function world(tIds)
        local J, bot, heroes = load_armed(CLOSE, tIds)
        set_hp(bot, 666)
        rawget(heroes['npc_dota_hero_earthshaker']:GetAbilityByName('earthshaker_fissure'),
            '__spec').GetCooldownTimeRemaining = 0
        return J, bot, heroes, rf.load_hero('crystal_maiden')
    end

    local J, bot, heroes, X = world({ 'cmrself' })
    assert(J.GetHP(bot) > X.nRSelfHpFloor and bot:WasRecentlyDamagedByAnyHero(X.nRSelfFireWindow),
        'the self clause is false only because of the health half')
    assert(J.GetReadyHardCc(heroes['npc_dota_hero_earthshaker']) ~= nil
        and GetUnitToUnitDistance(bot, heroes['npc_dota_hero_earthshaker'])
            <= 0 + X.nRGuardCloseBuffer,
        'a ready curated CC stands inside the enemy-side ring')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'but that gate is not armed, so it releases')

    local _, bot2, _, X2 = world({ 'cmrguard' })
    assert(X2.cm_IsRSafeToOpen(bot2) == false,
        'same world, enemy-side id: vetoed -- so the release above is the gating, '
        .. 'not an unreachable mutation')
end

-- ----------------------------------------------------------------- thresholds

tests['the health floor: both frames bracket it, and the band is scanned'] = function()
    local _, botA = load_armed(CLOSE, { 'cmrself' })
    local XA = rf.load_hero('crystal_maiden')
    local nFloor = XA.nRSelfHpFloor
    for _, f in ipairs({ 0.265, 0.30, 0.38, 0.45, 0.514 }) do
        XA.nRSelfHpFloor = f
        assert(XA.cm_IsRSafeToOpen(botA) == false,
            'frame A (26.3%) must be caught at floor ' .. f)
    end
    XA.nRSelfHpFloor = nFloor

    local _, botB = load_armed(REACH, { 'cmrself' })
    local XB = rf.load_hero('crystal_maiden')
    for _, f in ipairs({ 0.265, 0.30, 0.38, 0.45, 0.514 }) do
        XB.nRSelfHpFloor = f
        assert(XB.cm_IsRSafeToOpen(botB) == true,
            'frame B (51.5%) must be released at floor ' .. f)
    end
    XB.nRSelfHpFloor = nFloor
end

tests['the health floor: just outside the band each frame flips'] = function()
    local _, botA = load_armed(CLOSE, { 'cmrself' })
    local XA = rf.load_hero('crystal_maiden')
    local nFloor = XA.nRSelfHpFloor
    XA.nRSelfHpFloor = 0.26
    assert(XA.cm_IsRSafeToOpen(botA) == true, 'a floor under 26.3% releases the frame that died')
    XA.nRSelfHpFloor = nFloor

    local _, botB = load_armed(REACH, { 'cmrself' })
    local XB = rf.load_hero('crystal_maiden')
    XB.nRSelfHpFloor = 0.52
    assert(XB.cm_IsRSafeToOpen(botB) == false, 'a floor over 51.5% starts vetoing frame B')
    XB.nRSelfHpFloor = nFloor
end

tests['the health floor: pinned to one point of health either side'] = function()
    local _, bot = load_armed(CLOSE, { 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    -- 0.38 * 1110 = 421.8.
    set_hp(bot, 421)
    assert(X.cm_IsRSafeToOpen(bot) == false, '421/1110 = 37.93% is below the floor')
    set_hp(bot, 422)
    assert(X.cm_IsRSafeToOpen(bot) == true, '422/1110 = 38.02% is above it')
end

tests['the fire window: pinned either side of the real 0.2s-ago hit'] = function()
    local _, bot = load_armed(CLOSE, { 'cmrself' })
    local X = rf.load_hero('crystal_maiden')
    local nWin = X.nRSelfFireWindow
    X.nRSelfFireWindow = 0.1
    assert(X.cm_IsRSafeToOpen(bot) == true,
        'nothing hit her inside 0.1s, so a 26%-hp CM is released -- the fire half '
        .. 'really is read, it is not decoration on the health check')
    X.nRSelfFireWindow = 0.2
    assert(X.cm_IsRSafeToOpen(bot) == false, 'the Earthshaker hit at dt=0.2 is inside')
    X.nRSelfFireWindow = nWin
end

tests['the constants are the documented ones'] = function()
    load_armed(CLOSE, {})
    local X = rf.load_hero('crystal_maiden')
    assert(X.nRSelfHpFloor == 0.38,
        'the floor is deliberately the number the retreat branch already uses')
    assert(X.nRSelfFireWindow == 2.0, 'the window matches ConsiderQ in this file')
end

-- ------------------------------------------------------------------ end to end

tests['frame A end to end: shipped really bids HIGH here (not an empty green)'] = function()
    local nDesire = bid_considerR(CLOSE, {})
    assert(nDesire == BOT_ACTION_DESIRE_HIGH,
        'the real X.ConsiderR bids HIGH on the untouched frame: both enemies sit '
        .. 'inside the field AND inside the "cannot walk out" ring, so the '
        .. 'aoeCanHurtCount >= 2 branch fires. No mutation is needed to reach the gate')
end

tests['frame A end to end: `cmrself` armed turns that HIGH into NONE'] = function()
    local nDesire = bid_considerR(CLOSE, { 'cmrself' })
    assert(nDesire == BOT_ACTION_DESIRE_NONE, 'the channel is withheld')
end

tests['frame A end to end: moving ONLY her health puts the bid back'] = function()
    local nDesire = bid_considerR(CLOSE, { 'cmrself' }, function(_, bot)
        set_hp(bot, 666) -- 60% of 1110; nothing else on the frame moves
    end)
    assert(nDesire == BOT_ACTION_DESIRE_HIGH,
        'the veto is attributable to her health, not to anything else the arming touched')
end

tests['frame A end to end: non-turbo keeps the shipped bid'] = function()
    local nDesire = bid_considerR(CLOSE, { 'cmrself' }, function(J)
        J.IsModeTurbo = function() return false end
    end)
    assert(nDesire == BOT_ACTION_DESIRE_HIGH)
end

tests['frame B end to end: NONE on both sides, and for a reason that is stated'] = function()
    local nShipped, J, bot = bid_considerR(REACH, {})
    local nArmed = bid_considerR(REACH, { 'cmrself' })
    assert(nShipped == BOT_ACTION_DESIRE_NONE and nArmed == BOT_ACTION_DESIRE_NONE,
        'identical on both sides')
    -- Why it is NONE has nothing to do with this gate, and saying so keeps the
    -- case above from being an empty green: the field radius is 835*0.88 = 734.8
    -- and both enemies ARE inside it, but the branch also requires them to be
    -- inside nRadius*0.82 - movespeed = 302.5, and they stand at 536 and 557.
    local nRadius = 835 * 0.88
    local tIn = J.GetNearbyHeroes(bot, nRadius, true, BOT_MODE_NONE)
    assert(#tIn == 2, 'two enemies inside the field, so the bid is not vacuous for lack of targets')
    for _, h in pairs(tIn) do
        assert(GetUnitToUnitDistance(bot, h) > nRadius * 0.82 - h:GetCurrentMovementSpeed(),
            'but each of them can simply walk out, so aoeCanHurtCount stays 0')
    end
    assert(#tIn < 3, 'and the count branch needs three')
end

-- ---------------------------------------------------------------- source tripwires

tests['tripwire: one gate call behind one id, and the turbo check covers both blocks'] = function()
    local src = hero_source()
    local nIds = select(2, src:gsub("IsSoakCandidate%( 'cmrself' %)", ''))
    assert(nIds == 1, "exactly one 'cmrself' gate call in this file; found " .. nIds)
    assert(src:find("if not J.IsModeTurbo() then return true end", 1, true),
        'the shared turbo-only early return must stay at the top of the gate')
    assert(src:find("if J.IsSoakCandidate( 'cmrguard' )\n\tthen", 1, true),
        'the enemy-side ring scan must sit in its OWN candidate block -- folding '
        .. 'this clause back under cmrguard is the axeblink trap')
end

tests['tripwire: the clause is the conjunction of the two facts about her'] = function()
    local src = hero_source()
    assert(src:find("if J.IsSoakCandidate( 'cmrself' )\n"
        .. "\tand J.GetHP( hBot ) < X.nRSelfHpFloor\n"
        .. "\tand hBot:WasRecentlyDamagedByAnyHero( X.nRSelfFireWindow )\n"
        .. "\tthen", 1, true),
        'both halves must remain -- health alone silences the ultimate for most '
        .. 'of the game, fire alone silences it in every teamfight')
end

tests['tripwire: the floor still matches the retreat branch it was taken from'] = function()
    local src = hero_source()
    assert(src:find('J.IsRetreating( bot ) and nHP > 0.38', 1, true),
        "X.nRSelfHpFloor is 0.38 BECAUSE ConsiderR's retreat branch already draws "
        .. 'the line there; if that branch moves, this constant needs a fresh '
        .. 'argument rather than a stale citation')
end

return tests
