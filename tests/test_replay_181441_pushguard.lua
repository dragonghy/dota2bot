-- [pushguard / freehunt#2] Deep-solo-push abort, pinned by the REAL frame:
-- game 20260722_181441 t=524 (8:44). Luna (dire, winning side, MoM) rode the
-- wave to +6182..+7400 depth in the radiant top T3 area; Centaur was 260u on
-- her and Sniper ~900u, her nearest ally 4000+ away, TP off cooldown the
-- whole time -- she took no retreat action for 20 visible seconds and died
-- at 8:53 (died_after=6.9 in the fixture ground truth, killed while mana-dry).
-- The fixed decision: J.ShouldAbortDeepSoloPush is TRUE on this frame (armed),
-- so the push wrappers cap desire and the retreat floor takes her out.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')
local api = require('mock.bot_api')

local FIXTURE = 'tests/fixtures/f_181441_luna_deep_solo.lua'
local tests = {}

local function armed(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'pushguard'
    end
    -- Luna is DIRE here: her ancient top-right, the enemy's bottom-left.
    GetAncient = function(team) -- luacheck: ignore
        if team == GetTeam() then
            return api.MakeUnit({ GetLocation = api.Vector(5900, 5100, 0) })
        end
        return api.MakeUnit({ GetLocation = api.Vector(-5900, -5300, 0) })
    end
    return J, bot, heroes, fx
end

tests['FIRE: the 8:44 frame -- deep, solo, two defenders converging'] = function()
    local J, bot = armed()
    assert(J.ShouldAbortDeepSoloPush(bot) == true,
        'Luna died 6.9s after this frame doing exactly this -- abort the push')
end

tests['NO-FIRE: an ally arrives within 2500 -> a real push, not a feed'] = function()
    local J, bot, heroes = armed()
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() == bot:GetTeam() and h:IsAlive() then
            rawget(h, '__spec').GetLocation = bot:GetLocation()
            rawset(h, 'GetLocation', nil)
            break
        end
    end
    assert(J.ShouldAbortDeepSoloPush(bot) == false,
        'with company the deep push is a normal grouped push')
end

tests['NO-FIRE: only one visible defender -> the trade may be fine'] = function()
    local J, bot, heroes = armed()
    -- Push every enemy but the closest (centaur) out of the 1600 scan.
    local moved = false
    for _, name in ipairs({ 'npc_dota_hero_sniper' }) do
        if heroes[name] then
            rawget(heroes[name], '__spec').GetLocation = { x = 90000, y = 90000, z = 0 }
            rawset(heroes[name], 'GetLocation', nil)
            moved = true
        end
    end
    assert(moved, 'test setup: sniper must exist in the fixture')
    assert(J.ShouldAbortDeepSoloPush(bot) == false,
        'one visible defender is not the converging-collapse case')
end

tests['NO-FIRE: shallow position -> normal play'] = function()
    local J, bot = armed()
    rawget(bot, '__spec').GetLocation = { x = 4000, y = 3000, z = 0 } -- own half
    rawset(bot, 'GetLocation', nil)
    assert(J.ShouldAbortDeepSoloPush(bot) == false,
        'the guard only bites meaningfully past the midline')
end

tests['OFF: inert off the candidate / in normal mode'] = function()
    local J, bot = armed({ off = true })
    assert(J.ShouldAbortDeepSoloPush(bot) == false, 'candidate off -> inert')
    local J2, bot2 = armed()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J2.ShouldAbortDeepSoloPush(bot2) == false, 'normal mode -> inert')
end

return tests
