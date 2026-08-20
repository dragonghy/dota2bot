-- Replay-fixture regression for the `axeblink` guard on the FIRST real frame
-- where Axe actually owns and uses a Blink Dagger (hero backlog #5, GH #56 §5
-- "必须放行" frame).
--
-- Why this file exists on top of tests/test_replay_222428_axe_blink_call.lua:
-- that test pins the guard's inputs on a frame where Axe carries NO dagger
-- (its own caveat #1), and both of its crowd cases are MUTATIONS. Until the
-- `axebuyblink` reorder was armed on the farm, no frame of an Axe holding a
-- dagger existed anywhere in the corpus. The 04:11Z (a)-evidence wave produced
-- the first ones, and this is the single most load-bearing of them: the guard's
-- "Call is unavailable" clause is TRUE here, so the ONLY thing standing between
-- the shipped decision and a veto is the crowd clause -- and the blink that
-- clause lets through kills Skeleton King 6.1 seconds later.
--
-- Real frame: soak/spot_20260820_041137_1_7c8b5167…/20260820_043124_slot1
-- (seed 885, ARMED side), t=491.9 (8:11). Everything the guard reads is real:
--   * axe level 10, 1365/1711 HP, 137/395 mana, at (4048.8, -3108.2),
--   * axe_berserkers_call level 1 with 4.3s of cooldown left -- NOT castable,
--     while 137 mana is MORE than enough to pay for it, so "unavailable" here
--     means cooldown and nothing else,
--   * skeleton_king (enemy) at (3422.3, -3407.4) -- 694 away, i.e. inside the
--     shipped branch's 500..1200 window -- on 199/1221 HP (16%) with
--     Reincarnation on a 167.3s cooldown,
--   * and NO second enemy anywhere near him: the next closest is shadow_shaman,
--     ~2687 away from the landing point.
--
-- What the replay then shows (ground truth from the same .dem, event log):
--   t=492.3  axe casts item_blink        (the dagger reached his bag between
--                                         this snapshot and the next -- it is
--                                         in `items` at t=492.4, not at 491.9)
--   t=493.9  axe casts axe_culling_blade on skeleton_king
--   t=498.4  skeleton_king DIES to axe
-- and the fixture's own observed block records that Axe survived (died_after
-- nil) having taken 116 damage from SK in the following 5s.
--
-- POPULATION FACT measured this round (5 armed games of that wave, all the
-- mirror-valid ones with a surviving .dem): 10 blink casts, and the guard would
-- have held ZERO of them -- the landing point never carried 2 visible enemies
-- (exactly 1 in 5 of the 10 casts; the other 5 landed with none at all). So relaxing the
-- >= 2 threshold is the only way to make the guard fire in this population, and
-- THIS frame is the arithmetic proof that relaxing it to >= 1 is the wrong
-- direction: it would veto the blink that produced the kill.
--
-- CAVEATS, stated plainly:
--   1. Berserker's Call's mana cost is anchored from outside the frame (70 at
--      level 1, Liquipedia 2026-08) -- make_fixture.py does not dig ability
--      specs. The conclusion does not depend on the value: any cost <= 137
--      leaves the cooldown as the sole reason Call is unavailable.
--   2. The Call radius likewise is not in the dump. The guard reads
--      GetSpecialValueInt('radius') and falls back to 315; the fixture world
--      answers 0 for that reader, so the 315 fallback is the branch under test
--      and a test below asserts exactly that (if the dumper ever starts
--      carrying specials, this test says so instead of silently drifting).
--   3. The consumer adds RandomVector(150) to the landing point. The tests use
--      the un-jittered point and separately assert that no jitter of that size
--      can bring a second enemy inside the radius on this frame.
--   4. The consumer itself (X.ConsiderItemDesire['item_blink']) is not driven
--      end to end here; its wiring is pinned by the source tripwire in
--      tests/test_replay_222428_axe_blink_call.lua.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260820_043124_axe_blink_kill.lua'
local CALL_MANA_COST_LV1 = 70   -- Liquipedia 2026-08; not carried by the dump.
local CALL_RADIUS_FALLBACK = 315 -- the guard's own fallback, see caveat 2.
local BLINK_CAST_RANGE = 1200   -- shop stat; the shipped branch's outer window.

local tests = {}

--- Load the real frame with the gate armed. Subject is already Axe (fx.self),
--- so the fixture's observed ground truth stays attached to him.
local function load_axe()
    local J, bot, heroes, fx = rf.load(FIXTURE)
    local call = bot:GetAbilityByName('axe_berserkers_call')
    rawget(call, '__spec').GetManaCost = CALL_MANA_COST_LV1
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    return J, bot, call, heroes, fx
end

--- The landing point the shipped branch computes on this frame, using the real
--- helper it uses: toward the target, min(cast range, distance) away.
local function landing(J, bot, hTarget)
    local d = GetUnitToUnitDistance(bot, hTarget)
    if d > BLINK_CAST_RANGE then d = BLINK_CAST_RANGE end
    return J.GetUnitTowardDistanceLocation(bot, hTarget, d)
end

tests['ground truth: axe at 8:11 holding a 4.3s Call cooldown, lone 16% SK 694 away'] = function()
    local J, bot, call, heroes, fx = load_axe()
    assert(fx.time == 491.9, 'frame time')
    assert(bot:GetUnitName() == 'npc_dota_hero_axe', 'subject is Axe')
    assert(bot:GetHealth() == 1365 and bot:GetMaxHealth() == 1711, 'real HP')
    assert(bot:GetMana() == 137 and bot:GetMaxMana() == 395, 'real mana')
    assert(bot:GetLevel() == 10, 'real level')
    assert(call:GetLevel() == 1, 'Call really is learned')
    assert(call:GetCooldownTimeRemaining() == 4.3, 'Call really is on cooldown')

    local sk = heroes['npc_dota_hero_skeleton_king']
    assert(sk:GetTeam() ~= bot:GetTeam(), 'skeleton king is the enemy here')
    assert(sk:GetHealth() == 199 and sk:GetMaxHealth() == 1221,
        'SK really is at 16% -- this is a finishable target, not a brawl')
    local d = GetUnitToUnitDistance(bot, sk)
    assert(d > 690 and d < 700, 'SK really is ~694 away, got ' .. tostring(d))
    -- The shipped branch's own window: > 500 and <= blink cast range. Without
    -- this the frame would not reach the guard at all and the test is vacuous.
    assert(d > 500 and d <= BLINK_CAST_RANGE,
        'the shipped offensive-blink branch really would fire on this gap')
    assert(J.GetEnemiesNearLoc(landing(J, bot, sk), CALL_RADIUS_FALLBACK)[1] ~= nil,
        'and the landing point really has the target on it')
end

tests['ground truth: Call is unavailable by COOLDOWN only, so the guard reaches its last clause'] = function()
    local _, bot, call = load_axe()
    assert(call:IsFullyCastable() == false, 'Call is not castable this instant')
    assert(bot:GetMana() >= CALL_MANA_COST_LV1,
        'but he could pay for it -- the cooldown is the whole reason')
end

tests['ground truth: the crowd clause runs on the 315 fallback, not on a dumped special'] = function()
    local _, _, call = load_axe()
    assert(call:GetSpecialValueInt('radius') == 0,
        'the fixture world does not carry ability specials, so the guard uses '
        .. 'its 315 fallback; if this ever changes, re-anchor caveat 2')
end

tests['ground truth: exactly ONE enemy on the landing point'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    local near = J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK)
    assert(#near == 1, 'lone target, got ' .. tostring(#near))
    assert(near[1]:GetUnitName() == 'npc_dota_hero_skeleton_king', 'and it is SK')
end

-- Caveat 3: the consumer jitters the landing point by up to 150. On this frame
-- no jitter of that size can change the head count, so the conclusion holds for
-- every point the consumer could actually have picked.
tests['ground truth: no RandomVector(150) jitter can turn this into a crowd'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    local nSecond = nil
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive()
            and h:GetUnitName() ~= 'npc_dota_hero_skeleton_king' then
            local d = GetUnitToLocationDistance(h, land)
            if nSecond == nil or d < nSecond then nSecond = d end
        end
    end
    assert(nSecond ~= nil, 'there are other living enemies on this frame')
    assert(nSecond > CALL_RADIUS_FALLBACK + 150,
        'the second-closest enemy must stay out of reach of any jitter, got '
        .. tostring(nSecond))
end

tests['gate ON, UNTOUCHED real frame: the blink is NOT held (this one kills SK)'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == false,
        'jumping a lone 16% hero to finish it must stay allowed even with Call '
        .. 'on cooldown -- the replay shows this exact blink culling SK 1.6s '
        .. 'later and killing him at t=498.4')
end

tests['gate OFF (not turbo): inert on the same frame'] = function()
    local J, bot, _, heroes = load_axe()
    GetGameMode = function() return 1 end -- set after rf.load(); install() forces turbo
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, heroes['npc_dota_hero_skeleton_king'])) == false,
        'outside turbo the guard must never hold a blink')
end

tests['gate OFF (turbo, candidate not armed): inert on the same frame'] = function()
    local J, bot, _, heroes = load_axe()
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, heroes['npc_dota_hero_skeleton_king'])) == false,
        'turbo alone must not hold a blink without the axeblink id')
end

-- MUTATION of the real frame: bring the one other living enemy in reach
-- (shadow_shaman) onto SK. Everything else -- Call cooldown, mana, levels,
-- Axe's position -- is untouched, so this isolates the crowd clause as the ONE
-- thing separating "allow" from "hold" on this frame.
tests['MUTATION: same frame + a second enemy on the landing point => the blink IS held'] = function()
    local J, bot, _, heroes = load_axe()
    local sk = heroes['npc_dota_hero_skeleton_king']
    rawget(heroes['npc_dota_hero_shadow_shaman'], '__spec').GetLocation = sk:GetLocation()
    local land = landing(J, bot, sk)
    assert(#J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK) == 2, 'the landing point is now a crowd')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == true,
        'no Call and two enemies: that is the case the guard exists for')
end

-- Same crowd, Call available: the guard keys on Call availability, not on the
-- head count alone.
tests['MUTATION: crowd but Call ready => the blink is NOT held'] = function()
    local J, bot, call, heroes = load_axe()
    local sk = heroes['npc_dota_hero_skeleton_king']
    rawget(heroes['npc_dota_hero_shadow_shaman'], '__spec').GetLocation = sk:GetLocation()
    rawget(call, '__spec').GetCooldownTimeRemaining = 0
    assert(call:IsFullyCastable() == true, 'Call is castable once the cooldown is cleared')
    assert(J.ShouldHoldAxeBlinkForCall(bot, landing(J, bot, sk)) == false,
        'blinking into a crowd WITH Call is exactly what the dagger is for')
end

tests['the >= 2 threshold is load-bearing: a >= 1 rule would veto this kill'] = function()
    local J, bot, _, heroes = load_axe()
    local land = landing(J, bot, heroes['npc_dota_hero_skeleton_king'])
    -- The behavioural half: this frame sits at exactly one enemy and is allowed.
    assert(#J.GetEnemiesNearLoc(land, CALL_RADIUS_FALLBACK) == 1, 'one enemy')
    assert(J.ShouldHoldAxeBlinkForCall(bot, land) == false, 'and it is allowed')
    -- The source half: the constant that makes that true. Measured population
    -- (10 casts over 5 armed games) never reaches 2, so the standing temptation
    -- is to relax this to 1 -- which by the two assertions above would have
    -- vetoed the blink that killed SK.
    local f = assert(io.open('bots/FunLib/jmz_func.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function J%.ShouldHoldAxeBlinkForCall.-\nend')
    assert(body, 'could not locate J.ShouldHoldAxeBlinkForCall')
    assert(body:find('J%.GetEnemiesNearLoc%( vLandLoc, nRadius %) >= 2'),
        'the crowd threshold must stay at >= 2; see this test for why')
end

tests['the guard stays Axe-only on this frame'] = function()
    local J, bot, heroes = rf.load(FIXTURE, 'npc_dota_hero_skeleton_king')
    J.IsSoakCandidate = function(id) return id == 'axeblink' end
    assert(bot:GetUnitName() == 'npc_dota_hero_skeleton_king', 'subject override took')
    local axe = heroes['npc_dota_hero_axe']
    assert(J.ShouldHoldAxeBlinkForCall(bot, axe:GetLocation()) == false,
        'the guard is Axe-only; it must not touch any other hero blinking')
end

-- The fixture's own recorded consequences, so the "this blink was good" claim
-- is anchored in the dump rather than in this file's prose.
tests['ground truth: Axe survived the jump, paying 116 HP to SK for the kill'] = function()
    local _, _, _, _, fx = load_axe()
    assert(fx.observed.died_after == nil, 'Axe did not die in the ground-truth window')
    assert(fx.observed.burst['npc_dota_hero_skeleton_king'] == 116,
        'SK dealt 116 to him over the next 5s')
    local total = 0
    for _, e in ipairs(fx.observed.damage) do
        if e.actor == 'npc_dota_hero_skeleton_king' then total = total + e.value end
    end
    assert(total == 267, 'and 267 over the 30s horizon, got ' .. tostring(total))
end

return tests
