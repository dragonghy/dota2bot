local Defend = require( GetScriptDirectory()..'/FunLib/aba_defend')

local bot = GetBot()
local botName = bot:GetUnitName()

if bot:IsInvulnerable() or not bot:IsHero() or not string.find(botName, "hero") or bot:IsIllusion() then
	return
end

-- [tpcommit fix C] A fresh TP responder stays committed to the lane it
-- answered instead of being reclaimed by lane assignment mid-engagement;
-- floor from J.GetTpCommitDefendDesire (gated turbo + 'tpcommit', nil off).
local J = require( GetScriptDirectory()..'/FunLib/jmz_func')

function GetDesire()
	local nDesire = Defend.GetDefendDesire(bot, LANE_TOP)
	local nCommit = J.GetTpCommitDefendDesire(bot, LANE_TOP)
	if nCommit ~= nil and (nDesire == nil or nCommit > nDesire) then
		return nCommit
	end
	return nDesire
end
function Think() Defend.DefendThink(bot, LANE_TOP) end
