-- [midguard / obs 20260722 d21] Laning past-midline discipline contract for
-- J.ShouldRetreatPastMidline. Post-promote pattern (2 draft pools, ~17/25
-- focus deaths): cores die past the midline during laning, wandering deep
-- WITHOUT their wave. The smarter trigger avoids the force-passivity family:
--   FIRE     = turbo + 'midguard', laning core, > 800 past midline, NO allied
--              lane creeps within 900 (wave not with me), a visible enemy
--              within 1400, not committed/retreating -> step back.
--   NO-FIRE  = wave WITH me (deep CS is normal) / not deep / no enemy visible
--              / already committed -> false.
--   OFF      = not turbo / candidate off -> false.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	local enemy = api.MakeHero('npc_dota_hero_lich', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(1000, 200, 0),
	})
	-- Radiant bot deep past the midline: own ancient far, enemy ancient close.
	local depth = opts.shallow and api.Vector(-2000, 0, 0) or api.Vector(2000, 0, 0)
	local bot = api.MakeHero('npc_dota_hero_juggernaut', {
		CanBeSeen = true, GetLocation = depth,
		GetNearbyLaneCreeps = function(_, _r, bEnemy)
			if bEnemy then return {} end
			if opts.waveWithMe then
				return { api.MakeUnit({ CanBeSeen = true, IsAlive = true,
					GetLocation = api.Vector(depth.x + 300, 0, 0) }) }
			end
			return {}
		end,
		GetNearbyHeroes = function(_, _r, bEnemy)
			if bEnemy and not opts.noEnemy then return { enemy } end
			return {}
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	-- Ancients: radiant own at (-6000,0), enemy at (6000,0). Bot at x=+2000 ->
	-- own-dist 8000 vs enemy-dist 4000 -> depth +4000 (deep). Shallow variant
	-- x=-2000 -> depth -4000.
	GetAncient = function(team) -- luacheck: ignore
		if team == GetTeam() then
			return api.MakeUnit({ GetLocation = api.Vector(-6000, 0, 0) })
		end
		return api.MakeUnit({ GetLocation = api.Vector(6000, 0, 0) })
	end
	J.IsSoakCandidate = function(id) return opts.armed ~= false and id == 'midguard' end
	J.IsInLaningPhase = function() return true end
	J.IsCore = function() return opts.notCore ~= true end
	J.IsGoingOnSomeone = function() return opts.committed == true end
	J.IsRetreating = function() return false end

	return J, bot
end

tests['FIRE: deep past midline, no wave with me, enemy visible -> step back'] = function()
	local J, bot = scenario()
	assert(J.ShouldRetreatPastMidline(bot) == true,
		'deep + waveless + threatened is the exact d21 death setup -> retreat')
end

tests['NO-FIRE: my wave IS with me -> deep CS is normal, never fire'] = function()
	local J, bot = scenario({ waveWithMe = true })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'following the wave deep to CS is normal laning -- the guard must not touch it')
end

tests['NO-FIRE: not past the midline -> false'] = function()
	local J, bot = scenario({ shallow = true })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'on our own half normal logic owns everything')
end

tests['NO-FIRE: no enemy visible -> false (empty screen is just a walk)'] = function()
	local J, bot = scenario({ noEnemy = true })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'nobody to punish means no reason to interrupt the walk')
end

tests['NO-FIRE: already committed to a fight -> false (fight logic owns it)'] = function()
	local J, bot = scenario({ committed = true })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'an intentional commit is not wandering; the commit gates own that risk')
end

tests['NO-FIRE: not a core -> false'] = function()
	local J, bot = scenario({ notCore = true })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'support movement is owned by the support rules')
end

tests['OFF: inert off the candidate'] = function()
	local J, bot = scenario({ armed = false })
	assert(J.ShouldRetreatPastMidline(bot) == false,
		'gated: shipped behavior unchanged until the batch validates it')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldRetreatPastMidline(bot) == false, 'turbo-only')
end

return tests
