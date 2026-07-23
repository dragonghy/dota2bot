local Push = require( GetScriptDirectory()..'/FunLib/aba_push')
local bot = GetBot()
local botName = bot:GetUnitName()
if bot == nil or bot:IsInvulnerable() or not bot:IsHero() or not bot:IsAlive() or not string.find(botName, "hero") or bot:IsIllusion() then return end
if bot.PushLaneDesire == nil then bot.PushLaneDesire = {0, 0, 0} end

-- [pushguard freehunt#2] deep solo push vs converging defenders is a feed,
-- not a push (watched 181441 luna) -- cap the desire so retreat can win.
-- Gated (turbo + 'pushguard') inside the helper; inert by default.
local J = require( GetScriptDirectory()..'/FunLib/jmz_func')

function GetDesire()
    bot.PushLaneDesire[LANE_TOP] = Push.GetPushDesire(bot, LANE_TOP)
    if J.ShouldAbortDeepSoloPush(bot) then
        bot.PushLaneDesire[LANE_TOP] = math.min(bot.PushLaneDesire[LANE_TOP], 0.1)
    end
    return bot.PushLaneDesire[LANE_TOP]
end
function Think() Push.PushThink(bot, LANE_TOP) end
