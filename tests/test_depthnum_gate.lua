-- [GH #18] Depth-discount gating contract for J.SafeToCommitFight. Deep in
-- the enemy half, instantaneous VISIBLE parity overestimates safety (fog
-- reinforcements arrive within seconds -- iterations/0011 fight 24: a visible
-- 2v2 became a 2v4). The fix -- requiring numbers ADVANTAGE, not parity, when
-- the engage point is deep -- is Class-A and must NEVER ship untested: it is
-- inert unless the game is turbo AND this side is the active soak candidate
-- carrying the 'depthnum' id. Off the candidate side (the shipped default --
-- no Customize/soak_side file) deep parity must still read safe, so live
-- behavior is byte-for-byte unchanged. Mirrors tests/test_nodive_gate.lua.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_skeleton_king')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

-- Build a turbo SafeToCommitFight scenario where ONLY the numbers branch can
-- decide: the target is a valid enemy hero whose health (600) far exceeds the
-- mock's default estimated burst (0), so the LETHAL branch never fires. We pin
-- the ally/enemy pockets directly so each test controls parity vs advantage,
-- and place the ancients so the engage point (the target's location, the mock
-- default origin) is deep or not.
-- opts:
--   candidate: force the 'depthnum' soak candidate on (default off = shipped)
--   deep:      put the engage point deep in the enemy half (enemy ancient
--              1000u away, ours 8000u -- past the 1600u margin). Without it
--              both ancients sit at the origin (mock default), so the engage
--              point is NOT deep.
--   allies:    number of allied heroes at the engage point (incl. the bot)
--   enemies:   number of enemy heroes at the engage point
local function scenario(opts)
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    if opts.candidate then
        -- Force the gate open (no Customize/soak_side file exists in CI).
        J.IsSoakCandidate = function(id) return id == 'depthnum' end
    end
    if opts.deep then
        GetAncient = function(team)
            if team == GetOpposingTeam() then
                return api.MakeUnit({ GetLocation = Vector(1000, 0, 0) })
            end
            return api.MakeUnit({ GetLocation = Vector(8000, 0, 0) })
        end
    end
    local target = api.MakeHero('npc_dota_hero_enemy_target',
        { GetTeam = 3, CanBeSeen = true })
    local allies = { bot }
    for i = 2, opts.allies do
        allies[i] = api.MakeHero('npc_dota_hero_ally_' .. tostring(i),
            { CanBeSeen = true })
    end
    local enemies = { target }
    for i = 2, opts.enemies do
        enemies[i] = api.MakeHero('npc_dota_hero_enemy_' .. tostring(i),
            { GetTeam = 3, CanBeSeen = true })
    end
    J.GetAlliesNearLoc = function() return allies end
    J.GetEnemiesNearLoc = function() return enemies end
    return J, bot, target
end

tests['deep parity WITHOUT the depthnum candidate stays safe (live behavior unchanged)'] = function()
    local J, bot, target = scenario({ deep = true, allies = 2, enemies = 2 })
    assert(J.SafeToCommitFight(bot, target) == true,
        'off the candidate side deep 2v2 parity must still read safe -- the shipped numbers branch is untouched')
end

tests['candidate + deep + parity-only is NOT safe (fog-reinforcement discount)'] = function()
    local J, bot, target = scenario({ candidate = true, deep = true, allies = 2, enemies = 2 })
    assert(J.SafeToCommitFight(bot, target) == false,
        'deep in the enemy half, visible 2v2 parity must not read safe -- fog reinforcements make it a 2v4')
end

tests['candidate + deep + numbers ADVANTAGE is safe'] = function()
    local J, bot, target = scenario({ candidate = true, deep = true, allies = 3, enemies = 2 })
    assert(J.SafeToCommitFight(bot, target) == true,
        'deep engages with a real numbers advantage (+1) must still be allowed')
end

tests['candidate + NOT deep + parity is safe (discount only applies deep)'] = function()
    local J, bot, target = scenario({ candidate = true, deep = false, allies = 2, enemies = 2 })
    assert(J.SafeToCommitFight(bot, target) == true,
        'on our own half / near the midline, parity keeps its shipped meaning')
end

return tests
