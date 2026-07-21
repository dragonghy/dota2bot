-- Replay-fixture regression: game 20260720_071859, Oracle (the wandering
-- support the owner flagged: "神谕者莫名其妙乱跑,既不帮人也不推线也不补刀" --
-- the same systemic bug as Silencer in 071423).
--
-- Two frames:
--   * t=4:15 (screen): Oracle IS in lane, 362u from Chaos Knight. The lanefix
--     idle behavior must pick CK as the core to screen.
--   * t=4:32 (wandered): Oracle is at the fountain, 13k from CK. The helper
--     correctly finds nobody -- documenting that GetLaneCoreToProtect cannot
--     RECOVER an already-wandered support; prevention is the GetDesire
--     keep-in-lane half of the fix (mode-level, exercised in game, not here).
--
-- Roles are draft knowledge (world config), supplied to the mock role table --
-- decision logic itself runs unstubbed.

package.path = 'tests/?.lua;' .. package.path
local rf = require('mock.replay_fixture')

local tests = {}

local ROLES = {
    npc_dota_hero_chaos_knight = 1, npc_dota_hero_viper = 2,
    npc_dota_hero_sven = 3, npc_dota_hero_warlock = 4, npc_dota_hero_oracle = 5,
    npc_dota_hero_lich = 5, npc_dota_hero_ogre_magi = 4,
    npc_dota_hero_queen_of_pain = 2, npc_dota_hero_tidehunter = 3,
    npc_dota_hero_medusa = 1,
}

local function armed(fixture)
    local J, bot, heroes, fx = rf.load(fixture)
    J.IsSoakCandidate = function(id) return id == 'lf_support' end
    J.Role.GetPosition = function(u) return ROLES[u:GetUnitName()] or 5 end
    return J, bot, heroes, fx
end

tests['in lane: the screen target is the nearby carry'] = function()
    local J, bot, heroes = armed('tests/fixtures/f_071859_oracle_screen.lua')
    local core = J.GetLaneCoreToProtect(bot)
    assert(core == heroes['npc_dota_hero_chaos_knight'],
        'Oracle 362u from CK must screen CK')
end

tests['in lane: a support ally is never the screen target'] = function()
    -- Move CK far away; the remaining nearby allies are supports -> nil.
    local J, bot, heroes = armed('tests/fixtures/f_071859_oracle_screen.lua')
    rawget(heroes['npc_dota_hero_chaos_knight'], '__spec').GetLocation =
        Vector(6000, 6000, 0)
    local core = J.GetLaneCoreToProtect(bot)
    assert(core == nil or ROLES[core:GetUnitName()] <= 3,
        'only cores qualify as screen targets')
end

tests['wandered to fountain: nobody to screen (prevention is mode-level)'] = function()
    local J, bot = armed('tests/fixtures/f_071859_oracle_wandered.lua')
    assert(J.GetLaneCoreToProtect(bot) == nil,
        '13k from every core: the helper must not invent a target')
end

return tests
