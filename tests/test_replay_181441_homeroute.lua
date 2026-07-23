-- [homeroute / freehunt#3] Low-HP limbo router, pinned by the REAL frame:
-- game 20260722_181441 t=660 (11:00). Zeus at 16% (214/1354), empty bottle,
-- no salve/tango, nearest enemy ~3800u, ~6800u from the fountain -- and he
-- drifted there for 80 seconds (10:50-11:24) while his team wiped 4v5 mid;
-- his TP came off cooldown mid-limbo (16.6s remaining at this frame) and was
-- never used. The fixed decision: after the state persists 20s, COMMIT the
-- retreat to the fountain and run it to completion.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local FIXTURE = 'tests/fixtures/f_181441_zuus_lowhp_limbo.lua'
local tests = {}

local function armed(opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(FIXTURE)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'homeroute'
    end
    J.IsInLaningPhase = function() return opts.laning == true end
    -- Not captured by the dumper: the real distance-from-fountain (~6800 for
    -- this jungle spot; radiant fountain bottom-left).
    rawget(bot, '__spec').DistanceFromFountain = opts.fountainDist or 6800
    return J, bot, heroes, fx
end

tests['PERSISTENCE: the limbo frame stamps first, fires after 20s'] = function()
    local J, bot, _, fx = armed()
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'first sighting only stamps -- a brief dip must not yank the bot home')
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == true,
        'the same state 21s later IS the limbo -- commit the fountain route')
    assert(bot.homeRouteCommitted == true, 'commit flag must be set')
end

tests['MAINTENANCE: committed route does not stall at the 2500 ring'] = function()
    local J, bot, _, fx = armed()
    J.ShouldCommitFountainHeal(bot)
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == true, 'commit')
    -- Walked most of the way home, still 16% hp: keep going.
    rawget(bot, '__spec').DistanceFromFountain = 2000
    assert(J.ShouldCommitFountainHeal(bot) == true,
        'inside the initiation ring but still wrecked -> the route continues')
end

tests['RELEASE: healed (>=70%) clears the commitment'] = function()
    local J, bot, _, fx = armed()
    J.ShouldCommitFountainHeal(bot)
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == true, 'commit')
    local sp = rawget(bot, '__spec')
    sp.GetHealth = 1100  -- 81%
    sp.OriginalGetHealth = 1100
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'healed -> released back to normal desire logic')
    assert(bot.homeRouteCommitted == nil, 'commit flag must clear')
end

tests['NO-FIRE: a salve in the inventory -> use it, do not walk home'] = function()
    local J, bot, _, fx = armed()
    local api = require('mock.bot_api')
    local flask = api.MakeAbility('item_flask', { IsFullyCastable = true })
    rawget(bot, '__spec').GetItemInSlot = function(_, i)
        if i == 0 then return flask end
        return nil
    end
    assert(J.ShouldCommitFountainHeal(bot) == false, 'stamp only')
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'with a consumable the heal happens in place -- routing home wastes 30s')
end

tests['NO-FIRE: an enemy within 1400 -> normal retreat logic owns this'] = function()
    local J, bot, heroes, fx = armed()
    -- Pull one dire hero onto zeus.
    for _, h in pairs(heroes) do
        if h:GetTeam() ~= bot:GetTeam() and h:IsAlive() then
            rawget(h, '__spec').GetLocation = bot:GetLocation()
            rawset(h, 'GetLocation', nil)
            break
        end
    end
    assert(J.ShouldCommitFountainHeal(bot) == false, 'stamp blocked')
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'with a live threat the danger-based retreat handles it, not the router')
end

tests['NO-FIRE: before the 7-min boundary -> the lane candidates own low-HP handling'] = function()
    -- (Was a J.IsInLaningPhase stub; replaced by a HARD 7-min boundary after
    -- the C-group SILENT diagnosis: turbo laning soft-extends to 10min while
    -- net worth < 8000, which blocked the router for exactly the wrecked-and-
    -- poor heroes it exists for -- watched 113203 pudge.)
    local J, bot = armed()
    DotaTime = function() return 300 end -- luacheck: ignore
    J.ShouldCommitFountainHeal(bot)
    DotaTime = function() return 321 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false,
        'early-game low-HP is lf_salve/lane-recover territory, not this router')
end

tests['OFF: inert off the candidate / in normal mode'] = function()
    local J, bot, _, fx = armed({ off = true })
    J.ShouldCommitFountainHeal(bot)
    DotaTime = function() return fx.time + 21 end -- luacheck: ignore
    assert(J.ShouldCommitFountainHeal(bot) == false, 'candidate off -> inert')
    local J2, bot2 = armed()
    GetGameMode = function() return 1 end -- luacheck: ignore
    assert(J2.ShouldCommitFountainHeal(bot2) == false, 'normal mode -> inert')
end

return tests
