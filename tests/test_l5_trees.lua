-- [L5-TREES / LANING_PLAYBOOK] Creep-aggro-safe harass predicate. The aggro
-- mechanic: an attack order on an enemy HERO aggros enemy lane creeps within
-- ~500 of ME -- so a support harasses safely only from OFF the wave (owner:
-- stand in the treeline beside the lane, never on the creeps).
-- J.IsHarassCreepAggroSafe is the pure predicate; mode_laning's support harass
-- branch consults it only under turbo + 'l5trees' (shipped path unchanged).
-- TODO(fixture): pin with a real on-wave-harass frame from the next batch's
-- replays once one is scanned (support harassing with creeps < 500).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function mk(creepDists)
	api.reset_modules()
	local creeps = {}
	for _, d in ipairs(creepDists or {}) do
		creeps[#creeps + 1] = api.MakeUnit({
			CanBeSeen = true, IsAlive = true, GetLocation = api.Vector(d, 0, 0),
		})
	end
	local bot = api.MakeHero('npc_dota_hero_crystal_maiden', {
		CanBeSeen = true, GetLocation = api.Vector(0, 0, 0),
		GetNearbyLaneCreeps = function(_, radius, bEnemy)
			if not bEnemy then return {} end
			local out = {}
			for _, c in ipairs(creeps) do out[#out + 1] = c end
			return out
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
	return J, bot
end

tests['SAFE: no enemy lane creeps near me -> harass draws no aggro'] = function()
	local J, bot = mk({})
	assert(J.IsHarassCreepAggroSafe(bot) == true,
		'off the wave (no enemy creeps within 500) harassing is aggro-free')
end

tests['UNSAFE: enemy lane creeps beside me -> harassing would aggro them'] = function()
	local J, bot = mk({ 300 })
	assert(J.IsHarassCreepAggroSafe(bot) == false,
		'standing on the wave, an attack order on the enemy hero pulls its creeps onto me')
end

return tests
