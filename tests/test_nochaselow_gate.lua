-- [replay-review 071423/071903] Anti-suicide-CHASE guard gating contract.
-- J.ShouldNotChaseWhenLow must be inert unless the game is turbo AND this side
-- is the active soak candidate carrying the 'lanefix' id. When armed it fires
-- ONLY on the narrow "I'm low, not a safe commit, and an enemy can finish me"
-- case; a healthy bot, an unpunishable chase, or a clean group kill all fall
-- through so a genuinely safe finish still happens.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

local function make_target()
    return api.MakeHero('npc_dota_hero_enemy_a', { GetTeam = 3, CanBeSeen = true })
end

tests['ShouldNotChaseWhenLow is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldNotChaseWhenLow(bot, make_target()) == false,
        'normal mode must never suppress a chase')
end

tests['ShouldNotChaseWhenLow is inert off the soak candidate'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function() return false end
    assert(J.ShouldNotChaseWhenLow(bot, make_target()) == false,
        'off the candidate side the guard must not fire (baseline aggression)')
end

-- Armed turbo scenario: gate forced on, one enemy in range whose burst we
-- control, and no allies near the target (so the allies-excluding-self kill
-- exception stays off unless a test enables it).
local function armed(bot_spec)
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    J.IsSoakCandidate = function(id) return id == 'lanefix' end
    local e = make_target()
    J.GetEnemiesNearLoc = function() return { e } end
    J.GetAlliesNearLoc = function() return { bot } end
    J.GetTotalEstimatedDamageToTarget = function() return 500 end
    for k, v in pairs(bot_spec or {}) do
        rawget(bot, '__spec')[k] = v
    end
    return J, bot, e
end

tests['does NOT fire at healthy HP'] = function()
    local J, bot, e = armed({ OriginalGetHealth = 600, OriginalGetMaxHealth = 600,
        GetHealth = 600, GetMaxHealth = 600 })
    assert(J.ShouldNotChaseWhenLow(bot, e) == false,
        'a healthy bot may keep chasing')
end

tests['fires when low HP + not safe + punishable burst'] = function()
    local J, bot, e = armed({ OriginalGetHealth = 180, OriginalGetMaxHealth = 600,
        GetHealth = 180, GetMaxHealth = 600 })
    -- burst 500 >= 180*0.45 = 81 -> the enemy can finish the low bot.
    assert(J.ShouldNotChaseWhenLow(bot, e) == true,
        'low bot chasing into a punishable burst must stop')
end

tests['does NOT fire when nobody can punish (low burst)'] = function()
    local J, bot, e = armed({ OriginalGetHealth = 180, OriginalGetMaxHealth = 600,
        GetHealth = 180, GetMaxHealth = 600 })
    J.GetTotalEstimatedDamageToTarget = function() return 10 end
    assert(J.ShouldNotChaseWhenLow(bot, e) == false,
        'no real threat -> a low bot may still finish a safe chase')
end

tests['does NOT fire when allies EXCLUDING self secure the kill'] = function()
    -- Rewritten with the guard (fixture f_071423_luna_chase): the exception is
    -- lethal-only and excludes self -- an ally near the target whose burst
    -- covers the target's health means the low bot need not tank the trade.
    local J, bot, e = armed({ OriginalGetHealth = 180, OriginalGetMaxHealth = 600,
        GetHealth = 180, GetMaxHealth = 600 })
    local ally = api.MakeHero('npc_dota_hero_ally_a', { CanBeSeen = true })
    J.GetAlliesNearLoc = function() return { bot, ally } end
    -- Stubbed total-burst (500) >= target health (default 600)? No -- lower the
    -- target so the ally's burst finishes it.
    rawget(e, '__spec').GetHealth = 300
    assert(J.ShouldNotChaseWhenLow(bot, e) == false,
        'kill secured by allies without the low bot -> chase is allowed')
end

tests['fires when the only "numbers" are the low bot itself'] = function()
    -- The Luna trap: visible parity counted the dying bot as a full fighter.
    -- With no other ally near the target, the guard must fire regardless of
    -- what SafeToCommitFight would say.
    local J, bot, e = armed({ OriginalGetHealth = 180, OriginalGetMaxHealth = 600,
        GetHealth = 180, GetMaxHealth = 600 })
    J.SafeToCommitFight = function() return true end -- must be ignored now
    assert(J.ShouldNotChaseWhenLow(bot, e) == true,
        'numbers parity that includes the low bot must not exempt the chase')
end

return tests
