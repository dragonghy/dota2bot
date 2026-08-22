-- Replay-fixture pin for `cmrcap` (GH #63): cap the GetCastRange() term of
-- cmrguard's veto ring, so the +400 closing buffer keeps meaning "he still has
-- to walk in" instead of handing a ranged CC 400 free units of veto radius.
--
-- Both frames below are the SAME ability -- Witch Doctor's paralyzing_cask,
-- ready, held by the only vetoer on the frame -- at two distances, so what they
-- bound is a statement about RANGE and nothing else:
--
--   CLOSE  20260820_043039_slot1 t=515.5 (GH #63 section 3's frame). CM at
--          267/890 (30%), 600 mana, Freezing Field level 1 off cooldown. WD 546
--          units away, cask level 3 cd 0, 509 mana. She opened the channel here
--          for real, the cask landed, she was dead 0.2s later (the fixture's own
--          ground truth: died_after = 0.2). MUST STAY VETOED.
--   FAR    20260820_042009_slot1 t=497.0. CM at full health, 549 mana, ultimate
--          ready. WD 883 units away holding the same ready cask -- and no hard
--          CC lands on her in the next ten seconds; she lives another 101.9s
--          (died_after = 101.9). Today's gate withholds the ultimate here for
--          nothing. MUST BE RELEASED.
--
-- Nobody else vetoes on either frame, so neither case is decided by a second
-- holder: on CLOSE, Slardar is 571u out (crush is a self-radius CC, ring 400)
-- and Shadow Shaman's shackles/voodoo are both on cooldown; on FAR, Slardar is
-- 1468u out and the rest of the enemy team is across the map. The tests assert
-- this rather than assume it.
--
-- EXTERNAL ANCHOR (not in the dump -- make_fixture.py extracts no ability
-- specs): paralyzing_cask's cast range, 600, from the datafeed (`herodata`,
-- the shipping KV that GetCastRange() reads at runtime). It is stated here
-- because the STATUS QUO's answer depends on it -- and the offline table that
-- number was published against (GH #63's cap sweep) was wrong in 16 of its 23
-- entries, cask among them, 900 vs the real 600. The capped gate's answer does
-- NOT depend on it: any cast range >= the cap gives the same 600u ring, and
-- there is a test below that says so at 200/600/900/1200.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local CLOSE = 'tests/fixtures/f_260820_043039_cm_cask_close.lua'  -- must BLOCK
local FAR   = 'tests/fixtures/f_260820_042009_cm_cask_far.lua'    -- must ALLOW

local CASK_RANGE = 600                      -- external anchor, see header
local WD = 'npc_dota_hero_witch_doctor'

local function cask(heroes)
    return heroes[WD]:GetAbilityByName('witch_doctor_paralyzing_cask')
end

-- Place `unit` at `dist` units from `bot`, keeping the frame's real bearing.
local function move_to(bot, unit, dist)
    local b, u = bot:GetLocation(), unit:GetLocation()
    local dx, dy = u.x - b.x, u.y - b.y
    local d = math.sqrt(dx * dx + dy * dy)
    rawget(unit, '__spec').GetLocation = Vector(b.x + dx / d * dist, b.y + dy / d * dist, 0)
end

--- Load a frame, arm the ids in `tArmed`, anchor the cask's cast range, and run
--- the real X.cm_IsRSafeToOpen. Returns its verdict plus the world.
local function gate(path, tArmed, nRange, fTweak)
    local J, bot, heroes, fx = rf.load(path)
    J.IsSoakCandidate = function(id) return tArmed[id] == true end
    rawget(cask(heroes), '__spec').GetCastRange = nRange or CASK_RANGE
    if fTweak then fTweak(J, bot, heroes) end
    local X = rf.load_hero('crystal_maiden')
    return X.cm_IsRSafeToOpen(bot), J, bot, heroes, fx, X
end

local GUARD     = { cmrguard = true }
local GUARD_CAP = { cmrguard = true, cmrcap = true }
local CAP_ONLY  = { cmrcap = true }

local tests = {}

tests['ground truth CLOSE: WD 546u, ready cask, and she died 0.2s into the channel'] = function()
    local _, J, bot, heroes, fx = gate(CLOSE, {})
    assert(fx.self == 'npc_dota_hero_crystal_maiden' and fx.time == 515.5, 'decision instant')
    assert(bot:GetHealth() == 267 and bot:GetMaxHealth() == 890, 'CM hp on the real frame')
    assert(math.floor(GetUnitToUnitDistance(bot, heroes[WD])) == 545, 'WD distance (545.99)')
    assert(J.GetReadyHardCc(heroes[WD]) ~= nil, 'his cask is leveled and off cooldown')
    assert(fx.observed.died_after == 0.2, 'she opened R here for real and died 0.2s later')

    -- Sole vetoer: the two enemies standing nearer than 1600 hold nothing ready.
    local slardar = heroes['npc_dota_hero_slardar']
    assert(math.floor(GetUnitToUnitDistance(bot, slardar)) == 571, 'slardar distance')
    assert(J.GetReadyHardCc(slardar) ~= nil, 'crush IS ready -- but it is a self-radius CC')
    local ss = heroes['npc_dota_hero_shadow_shaman']
    assert(J.GetReadyHardCc(ss) == nil, 'shackles 7.2s and voodoo 14.8s from ready')
end

tests['ground truth FAR: WD 883u, ready cask, no CC ever arrives and she lives 101.9s'] = function()
    local _, J, bot, heroes, fx = gate(FAR, {})
    assert(fx.self == 'npc_dota_hero_crystal_maiden' and fx.time == 497.0, 'decision instant')
    assert(bot:GetHealth() == 978 and bot:GetMaxHealth() == 978, 'CM is at full health here')
    assert(math.floor(GetUnitToUnitDistance(bot, heroes[WD])) == 882, 'WD distance')
    assert(J.GetReadyHardCc(heroes[WD]) ~= nil, 'same ability, same ready state, farther away')
    assert(fx.observed.died_after == 101.9, 'nothing interrupted her -- this veto buys nothing')
    assert(math.floor(GetUnitToUnitDistance(bot, heroes['npc_dota_hero_slardar'])) == 1468,
        'the only other CC holder in the scan is 1468u out, far outside his 400u ring')
end

tests['gates OFF: both frames allowed, shipped path untouched'] = function()
    assert(gate(CLOSE, {}) == true, 'off the candidates nothing may change')
    assert(gate(FAR, {}) == true, 'off the candidates nothing may change')
end

tests['STATUS QUO (cmrguard alone): catches CLOSE -- and pays for it on FAR'] = function()
    assert(gate(CLOSE, GUARD) == false, 'the true positive: 546u cask that really did land')
    assert(gate(FAR, GUARD) == false,
        'the false positive GH #63 measured: 883u <= 600 + 400, so the ultimate is withheld')
end

tests['cmrcap ON: CLOSE still blocked, FAR released'] = function()
    assert(gate(CLOSE, GUARD_CAP) == false,
        '546u <= min(600,200) + 400 = 600 -- narrowing must not undo the original catch')
    assert(gate(FAR, GUARD_CAP) == true,
        '883u > 600 -- a cask holder that far away is not why she should hold the channel')
end

tests['cmrcap armed ALONE is a no-op: it narrows cmrguard, it does not gate anything'] = function()
    assert(gate(CLOSE, CAP_ONLY) == true, 'without cmrguard there is no ring to cap')
    assert(gate(FAR, CAP_ONLY) == true, 'without cmrguard there is no ring to cap')
    -- Scheduling consequence, asserted so it cannot be forgotten: armed alone,
    -- this id is byte-identical to shipped (the axeblink trap). It has to ride
    -- the same arm as cmrguard or it measures nothing.
    assert(gate(CLOSE, CAP_ONLY) == gate(CLOSE, {}), 'cap-only == shipped')
    assert(gate(FAR, CAP_ONLY) == gate(FAR, {}), 'cap-only == shipped')
end

-- Clause isolation (GH #86's lesson: a pair of opposite-outcome frames only
-- pins the axis they differ on, and a test that flips both together proves
-- nothing). These two walk ONE frame across the boundary and nothing else.

tests['isolation: FAR is released by DISTANCE, not by WD ceasing to be a vetoer'] = function()
    local ok, J, _, heroes = gate(FAR, GUARD_CAP, CASK_RANGE, function(_, bot, hs)
        move_to(bot, hs[WD], 500)                      -- MUTATION of the real frame
    end)
    assert(J.GetReadyHardCc(heroes[WD]) ~= nil, 'the same ability is still ready')
    assert(ok == false, 'walked inside the capped ring, the very same cask vetoes again')
end

tests['isolation: CLOSE is caught by DISTANCE, not by anything special to that game'] = function()
    local ok = gate(CLOSE, GUARD_CAP, CASK_RANGE, function(_, bot, hs)
        move_to(bot, hs[WD], 700)                      -- MUTATION of the real frame
    end)
    assert(ok == true, 'the 546u catch is a fact about 546 units, not about that fight')
end

tests['the capped answer does not depend on the cast-range anchor'] = function()
    for _, r in ipairs({ 200, 600, 900, 1200 }) do
        assert(gate(CLOSE, GUARD_CAP, r) == false, 'CLOSE blocked at cask range ' .. r)
        assert(gate(FAR, GUARD_CAP, r) == true, 'FAR released at cask range ' .. r)
    end
end

tests['...whereas the STATUS QUO answer is an artifact of that anchor'] = function()
    -- 883 - 400 = 483: today's gate flips on FAR at a cast range nobody measured
    -- from the replay. It was published against 900 and the real value is 600 --
    -- both above 483, which is exactly why the false positive survived a
    -- re-anchoring that moved the number by 300 units.
    assert(gate(FAR, GUARD, 400) == true, 'a 400-range CC would not reach: allowed')
    assert(gate(FAR, GUARD, 600) == false, 'the real 600: withheld')
    assert(gate(FAR, GUARD, 900) == false, 'the wrong 900 it was published against: withheld')
end

tests['a self-radius CC is untouchable by the cap, by construction'] = function()
    for _, d in ipairs({ 350, 450 }) do
        local tweak = function(_, bot, hs) move_to(bot, hs[WD], d) end
        assert(gate(FAR, GUARD, 0, tweak) == gate(FAR, GUARD_CAP, 0, tweak),
            'at cast range 0 the ring is the buffer alone, capped or not (d=' .. d .. ')')
    end
    -- and the buffer alone still decides: inside 400 vetoes, outside does not.
    assert(gate(FAR, GUARD_CAP, 0, function(_, bot, hs) move_to(bot, hs[WD], 350) end) == false)
    assert(gate(FAR, GUARD_CAP, 0, function(_, bot, hs) move_to(bot, hs[WD], 450) end) == true)
end

tests['the cap only ever RELEASES: capped vetoes are a subset of uncapped ones'] = function()
    local nDiff = 0
    for d = 100, 1500, 50 do
        local tweak = function(_, bot, hs) move_to(bot, hs[WD], d) end
        local bPlain = gate(FAR, GUARD, CASK_RANGE, tweak)
        local bCap = gate(FAR, GUARD_CAP, CASK_RANGE, tweak)
        if bPlain == false and bCap == true then nDiff = nDiff + 1 end
        assert(not (bPlain == true and bCap == false),
            'the cap must never create a veto (d=' .. d .. ')')
    end
    -- ...and it is not vacuous: there really are distances where they differ.
    assert(nDiff > 0, 'if the cap changed nothing at any distance it would be dead code')
end

tests['the cap sits inside the window the two real frames bound'] = function()
    -- Both bounds are computed from the frames themselves, so they cannot drift
    -- away from the fixtures if either is ever regenerated.
    local _, _, botC, heroesC = gate(CLOSE, {})
    local dClose = GetUnitToUnitDistance(botC, heroesC[WD])
    local _, _, botF, heroesF = gate(FAR, {})
    local dFar = GetUnitToUnitDistance(botF, heroesF[WD])
    local X = rf.load_hero('crystal_maiden')
    assert(X.nRGuardRangeCap >= dClose - X.nRGuardCloseBuffer,
        'below ~146 the 546u cask that really did stun her out of the channel is released')
    assert(X.nRGuardRangeCap < dFar - X.nRGuardCloseBuffer,
        'at or above ~483 the 883u false positive comes back')
end

tests['turbo only: outside turbo the gate is unconditionally open'] = function()
    local J, bot = rf.load(CLOSE)
    GetGameMode = function() return 1 end     -- set after rf.load(): install() forces turbo
    J.IsSoakCandidate = function(id) return id == 'cmrguard' or id == 'cmrcap' end
    local X = rf.load_hero('crystal_maiden')
    assert(X.cm_IsRSafeToOpen(bot) == true, 'both ids are turbo-scoped')
end

tests['wiring: the cap is applied to the cast range, never to the closing buffer'] = function()
    local f = assert(io.open('bots/BotLib/hero_crystal_maiden.lua', 'r'))
    local src = f:read('*a')
    f:close()
    local body = src:match('function X%.cm_IsRSafeToOpen%( hBot %)(.-)\nend')
    assert(body, 'could not locate X.cm_IsRSafeToOpen')
    assert(body:match("math%.min%(%s*nCcRange,%s*X%.nRGuardRangeCap%s*%)"),
        'the cap must clamp the GetCastRange() term')
    assert(body:match('nCcRange%s*%+%s*X%.nRGuardCloseBuffer'),
        'and the buffer must still be added outside the clamp')
    assert(body:find("J.IsSoakCandidate( 'cmrcap' )", 1, true), 'the narrowing stays gated')
    assert(body:find("J.IsSoakCandidate( 'cmrguard' )", 1, true) <
        body:find("J.IsSoakCandidate( 'cmrcap' )", 1, true),
        'cmrcap lives inside the cmrguard branch -- armed alone it must be inert')
end

return tests
