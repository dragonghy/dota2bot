-- [TeamBrain phase 1 / wave12 dossier 20260725] TP response arbitration,
-- pinned on the dossier's flagship frames:
--
--   * f_050713 t=573 (ES): Earthshaker cast a defend TP into a destination
--     with 1 ally vs 3 visible enemies, landed, and died in 5.8s with ZERO
--     output. The headcount check must refuse this cast.
--   * f_045650 t=419 (Lion): Centaur had died at that same top tower 22s
--     earlier; Lion TP'd into the same DP meat grinder anyway (then Lina,
--     twice -- four bodies for one tower). The defeat memory must refuse it.
--   * 044941 t=343.2: THREE same-frame TPs answered one diving Axe -- the
--     single-responder claim must hold across bots (synthetic here: two
--     claims 1s apart on the same spot).
--
-- Gate contract: 'teambrain' off => ShouldAllowDefendTp is always TRUE
-- (stock behavior untouched); armed turbo => the four checks bite.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local function loaded(fixture, opts)
    opts = opts or {}
    local J, bot, heroes, fx = rf.load(fixture)
    J.IsSoakCandidate = function(id)
        return opts.off ~= true and id == 'teambrain'
    end
    return J, bot, heroes, fx
end

tests['[headcount] the ES 1v3 destination is refused'] = function()
    local J, bot, heroes = loaded('tests/fixtures/f_050713_es_defend_1v3.lua')
    -- The destination = the mid tower where DP stood vs OD/lina/lion. The
    -- 1Hz snapshot (t=573.0) has the three attackers still converging at
    -- 2837-3151; the dossier's CAST-instant readout (t=573.5) has them at
    -- 1096/1116/1272 -- pin those positions (ES died 9.3s later).
    local dp = heroes['npc_dota_hero_death_prophet']
    local v = dp:GetLocation()
    local atk = { npc_dota_hero_obsidian_destroyer = 1096,
                  npc_dota_hero_lina = 1116, npc_dota_hero_lion = 1272 }
    for name, d in pairs(atk) do
        local sp = rawget(heroes[name], '__spec')
        sp.GetLocation = { x = v.x + d, y = v.y, z = 0 }
        rawset(heroes[name], 'GetLocation', nil)
    end
    assert(J.ShouldAllowDefendTp(bot, v) == false,
        'one ally vs three visible enemies at the landing = a body donation')
end

tests['[transparency] teambrain off -> the same cast is allowed (shipped default)'] = function()
    local J, bot, heroes = loaded('tests/fixtures/f_050713_es_defend_1v3.lua',
        { off = true })
    local dp = heroes['npc_dota_hero_death_prophet']
    assert(J.ShouldAllowDefendTp(bot, dp:GetLocation()) == true,
        'off the candidate the arbitrator must be a no-op')
end

tests['[defeat memory] the lion meat-grinder tower is refused for 25s'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_045650_lion_meatgrinder.lua')
    -- Ground truth: centaur died at the top tower ~22s before lion's TP.
    local vTower = { x = -6350, y = 4800, z = 0 } -- the contested top tower area
    local centaur = { GetLocation = function() return vTower end }
    DotaTime = function() return fx.time - 22 end -- luacheck: ignore
    J.NoteTeamDeath(centaur)
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(bot, vTower) == false,
        'a teammate died here 22s ago -- do not feed the same grinder')
    -- 26s later the memory has expired; with a sane headcount it may answer.
    DotaTime = function() return fx.time + 4 end -- luacheck: ignore
    local vQuiet = { x = -900, y = -900, z = 0 } -- own half, nobody visible
    assert(J.ShouldAllowDefendTp(bot, vQuiet) == true,
        'the memory is spot-scoped and time-boxed, not a blanket TP ban')
end

tests['[single responder] a fresh claim by another bot blocks the second TP'] = function()
    local J, bot, heroes, fx = loaded('tests/fixtures/f_045650_lion_meatgrinder.lua')
    local vSpot = { x = 2000, y = 2000, z = 0 }
    -- First responder (another player id) claims the event.
    local mate
    for _, h in pairs(heroes) do
        if h ~= bot and h:GetTeam() == bot:GetTeam() and h:IsAlive() then
            mate = h
            break
        end
    end
    assert(mate ~= nil, 'setup: need a teammate')
    -- The mock defaults every hero to player id 0; the claim is per-player.
    rawget(mate, '__spec').GetPlayerID = 7
    rawget(bot, '__spec').GetPlayerID = 2
    DotaTime = function() return fx.time end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(mate, vSpot) == true, 'first responder claims')
    assert(J.ShouldAllowDefendTp(bot, vSpot) == false,
        'the answer is already in the air -- 343.2s had THREE same-frame TPs')
    DotaTime = function() return fx.time + 13 end -- luacheck: ignore
    assert(J.ShouldAllowDefendTp(bot, vSpot) == true,
        'a stale claim (>12s) releases the event')
end

tests['[revive cooldown] a fresh respawn never answers a defend TP'] = function()
    local J, bot, _, fx = loaded('tests/fixtures/f_050713_es_defend_1v3.lua')
    DotaTime = function() return fx.time end -- luacheck: ignore
    bot.lastDeadFrameTime = fx.time - 10
    local vQuiet = { x = -900, y = -900, z = 0 }
    assert(J.ShouldAllowDefendTp(bot, vQuiet) == false,
        '6/24 dossier deaths were revive->TP->re-death within 14-23s')
end

return tests
