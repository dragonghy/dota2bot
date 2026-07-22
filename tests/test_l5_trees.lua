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

-- ---- cut 2: off-wave harass spot (J.GetOffWaveHarassSpot) ----

-- Geometry scenario: enemy wave at my feet (creeps 200-300 away), one enemy
-- laner at (600,0); my fountain at (0,-6000) so the lane axis points -y and
-- the perpendicular is +-x. The spot must sidestep ~550 and pick the side
-- AWAY from the enemy (negative x).
local function mk2(opts)
	opts = opts or {}
	api.reset_modules()
	local creeps = {
		api.MakeUnit({ CanBeSeen = true, IsAlive = true, GetLocation = api.Vector(250, 100, 0) }),
		api.MakeUnit({ CanBeSeen = true, IsAlive = true, GetLocation = api.Vector(300, -100, 0) }),
	}
	local enemy = api.MakeHero('npc_dota_hero_viper', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(600, 0, 0),
	})
	local bot = api.MakeHero('npc_dota_hero_crystal_maiden', {
		CanBeSeen = true, GetLocation = api.Vector(0, 0, 0),
		GetHealth = 500, OriginalGetHealth = 500, OriginalGetMaxHealth = 600,
		GetNearbyLaneCreeps = function(_, radius, bEnemy)
			if not bEnemy or opts.noCreeps then return {} end
			return creeps
		end,
		GetNearbyHeroes = function(_, _r, bEnemy)
			if bEnemy and not opts.noEnemy then return { enemy } end
			return {}
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
	J.GetTeamFountain = function() return api.Vector(0, -6000, 0) end
	return J, bot
end

tests['SPOT: on-wave with a target -> sidestep ~550 on the side away from the enemy'] = function()
	local J, bot = mk2()
	local v = J.GetOffWaveHarassSpot(bot)
	assert(v ~= nil, 'on-wave + harass target must yield a sidestep spot')
	assert(math.abs(math.abs(v.x) - 550) < 60 or math.abs(v.x) > 400,
		'the spot steps roughly perpendicular to the lane axis')
	assert(v.x < 0, 'the side AWAY from the enemy laners (enemy at +x) must be chosen')
end

tests['SPOT nil: not on the wave (already aggro-safe) -> no sidestep needed'] = function()
	local J, bot = mk2({ noCreeps = true })
	assert(J.GetOffWaveHarassSpot(bot) == nil,
		'off the wave the harass branch itself handles it; no move')
end

tests['SPOT nil: nobody to harass -> no sidestep'] = function()
	local J, bot = mk2({ noEnemy = true })
	assert(J.GetOffWaveHarassSpot(bot) == nil,
		'without a harass target the sidestep is pointless wandering')
end

return tests
