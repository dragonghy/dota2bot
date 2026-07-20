-- [GH #4] Anti-suicide-dive guard gating contract. The dive suppression must
-- NEVER ship untested: J.ShouldSuppressDive is inert unless the game is turbo
-- AND this side is the active soak candidate carrying the 'nodive' id. Off the
-- candidate side (the shipped default -- no Customize/soak_side file) it must
-- return false so baseline aggression is untouched. Also pins the trivial
-- J.SafeToCommitFight contract for a missing target (nothing to gate => safe).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh_jmz()
    api.reset_modules()
    local bot = api.MakeHero('npc_dota_hero_lion')
    api.install({ bot = bot })
    return require(GetScriptDirectory() .. '/FunLib/jmz_func'), bot
end

tests['ShouldSuppressDive is inert in normal (non-turbo) mode'] = function()
    local J, bot = fresh_jmz()
    GetGameMode = function() return 1 end
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'normal mode must never suppress a dive')
end

tests['ShouldSuppressDive in turbo is live but stays off with no enemy pocket (PROMOTED)'] = function()
    -- PROMOTED under the Class-B micro-behavior policy (runbook §1): turbo no
    -- longer requires a soak candidate. The default mock has no enemies near
    -- the engage point, so the guard must still fall through — promotion must
    -- not make it fire outside the narrow "2+ flankers, near-certain feed" case.
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'turbo with no flanking enemies must never suppress a dive')
end

tests['SafeToCommitFight treats a missing target as safe'] = function()
    local J, bot = fresh_jmz()
    assert(J.SafeToCommitFight(bot, nil) == true,
        'no valid target means there is no dive to gate')
end

-- Build an active-candidate turbo scenario: 2+ enemies at the engage point and
-- NOT safe to commit (outnumbered, no kill). We force the gate on and pin the
-- ally/enemy pockets directly so the test exercises ONLY the sharpened
-- lethal-or-no-escape tightening, not the gating or the numbers/lethal gate.
local function armed_scenario(bot_spec)
    local J, bot = fresh_jmz()
    GetGameMode = function() return GAMEMODE_TURBO end
    -- Force the gate open (no Customize/soak_side file exists in CI).
    J.IsSoakCandidate = function(id) return id == 'nodive' end
    -- Two flanking enemies at the engage point; the bot is outnumbered (allies
    -- = just the bot) and their default estimated burst is 0, so
    -- J.SafeToCommitFight is false and we always reach the tightening.
    local e1 = api.MakeHero('npc_dota_hero_enemy_a', { GetTeam = 3, CanBeSeen = true })
    local e2 = api.MakeHero('npc_dota_hero_enemy_b', { GetTeam = 3, CanBeSeen = true })
    J.GetEnemiesNearLoc = function() return { e1, e2 } end
    J.GetAlliesNearLoc = function() return { bot } end
    -- Apply per-test overrides on the bot.
    for k, v in pairs(bot_spec or {}) do
        rawget(bot, '__spec')[k] = v
    end
    return J, bot
end

tests['ShouldSuppressDive does NOT fire in an even-HP walk-out'] = function()
    -- Bot at full HP, mobile, no lockdown, negligible incoming burst: it can
    -- just step out, so the sharpened guard must fall through to normal logic.
    local J, bot = armed_scenario({
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600, -- GetHP = 1.0
        GetHealth = 600,
        GetCurrentMovementSpeed = 320,
    })
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == false,
        'even-HP, mobile walk-out must not trigger a hard retreat')
end

tests['ShouldSuppressDive fires when the bot is already low HP'] = function()
    local J, bot = armed_scenario({
        OriginalGetHealth = 180, OriginalGetMaxHealth = 600, -- GetHP = 0.30
        GetHealth = 180,
        GetCurrentMovementSpeed = 320,
    })
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == true,
        'low-HP dive into 2+ enemies with no kill is a feed; suppress it')
end

tests['ShouldSuppressDive fires when the bot cannot escape (too slow)'] = function()
    local J, bot = armed_scenario({
        OriginalGetHealth = 600, OriginalGetMaxHealth = 600, -- GetHP = 1.0
        GetHealth = 600,
        GetCurrentMovementSpeed = 200, -- can't outrun the pocket
    })
    assert(J.ShouldSuppressDive(bot, bot:GetLocation(), nil) == true,
        'no-escape (slowed) dive into 2+ enemies must trigger the guard')
end

return tests
