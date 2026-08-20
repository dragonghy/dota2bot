-- [GH #48] J.CanBreakTeleport called a name that does not exist.
--
-- `J.GetCastPoint` has never been defined on J; the neighbouring helper is
-- `J.GetCastDelay` (identical signature). So the ONLY branch that matters --
-- the one taken when the target really is channeling a teleport -- raised
-- `attempt to call field 'GetCastPoint' (a nil value)` instead of answering.
--
-- Two things hid it: the function has no callers in bots/ (it is a landmine for
-- whoever wires it up first, not a live crash), and until commit eb74722 taught
-- make_fixture.py to rebuild per-frame modifiers, `HasModifier(anything)` was
-- false in every fixture -- so the body was unreachable under test as well and
-- the function was, in the test world, a constant `return true`.
--
-- The frame below is the first one in the corpus that can reach the body:
-- 20260819_223607_slot1 @ t=563.5, drow_ranger channeling a TP (started 560.3,
-- landed intact at 565.3), modifier_teleporting remaining 1.8s.
--
-- The two-way assertion is the point. Fixing a crash by returning a constant
-- would also stop the crash; these tests fail unless the body really compares
-- the cast delay against the remaining channel time.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_260819_223607_sniper_rooted.lua'
local TELEPORTER = 'npc_dota_hero_drow_ranger'
local REMAINING = 1.8 -- ground truth from the fixture's modifier block

local tests = {}

local function frame()
    local J, bot, heroes = rf.load(FIXTURE)
    return J, bot, heroes[TELEPORTER]
end

tests['ground truth: the fixture frame really has a hero channeling a TP'] = function()
    local J, _, drow = frame()
    assert(drow ~= nil, 'fixture must contain ' .. TELEPORTER)
    assert(drow:HasModifier('modifier_teleporting'),
        'the frame must carry a live modifier_teleporting (this is what eb74722 made possible)')
    local left = J.GetModifierTime(drow, 'modifier_teleporting')
    assert(math.abs(left - REMAINING) < 0.05,
        'remaining channel time should be ' .. REMAINING .. 's, got ' .. tostring(left))
end

tests['GH #48: the teleporting branch no longer crashes'] = function()
    local J, bot, drow = frame()
    local ok, res = pcall(J.CanBreakTeleport, bot, drow, 2.0, 0)
    assert(ok, 'J.CanBreakTeleport raised on a real teleporting target: ' .. tostring(res))
end

tests['a 2.0s cast cannot beat 1.8s of channel left'] = function()
    local J, bot, drow = frame()
    assert(J.CanBreakTeleport(bot, drow, 2.0, 0) == false,
        'a 2.0s cast delay must NOT be reported as able to break a 1.8s channel'
            .. ' (ground truth: that TP landed intact at t=565.3)')
end

tests['a 0.3s cast does beat 1.8s of channel left'] = function()
    local J, bot, drow = frame()
    assert(J.CanBreakTeleport(bot, drow, 0.3, 0) == true,
        'a 0.3s cast delay must be reported as able to break a 1.8s channel')
end

-- Reverse assertion: the no-modifier path is PUBLISHED behavior and must stay
-- `return true` -- the fix must not turn it into "measure everything".
tests['no modifier_teleporting still returns true regardless of cast delay'] = function()
    local J, bot, heroes = rf.load(FIXTURE)
    local lich = heroes['npc_dota_hero_lich']
    assert(lich ~= nil and not lich:HasModifier('modifier_teleporting'),
        'need a hero on this frame that is NOT teleporting')
    assert(J.CanBreakTeleport(bot, lich, 99.0, 0) == true,
        'a target that is not channeling must return true even for an absurd cast delay')
end

-- The distance term only enters when a projectile speed is given. Pinning this
-- documents the caveat in the source comment: with nProjectSpeed == 0 the 11.7k
-- units between sniper and drow contribute nothing, and the same call with a
-- finite projectile speed answers differently on the very same frame.
tests['projectile speed is what brings the distance term in'] = function()
    local J, bot, drow = frame()
    local dist = GetUnitToUnitDistance(bot, drow)
    assert(dist > 5000, 'this frame is meant to be a long-range pair, got ' .. tostring(dist))
    assert(J.CanBreakTeleport(bot, drow, 0.3, 0) == true,
        'speed 0 drops the distance term, so 0.3s stays under 1.8s')
    assert(J.CanBreakTeleport(bot, drow, 0.3, 2500) == false,
        'at 2500 u/s the projectile alone needs ' .. string.format('%.1f', dist / 2500)
            .. 's, which cannot beat 1.8s')
end

return tests
