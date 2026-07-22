-- [GH #10] Creep-pull / 勾线 trigger + gating contract. A disadvantaged laning
-- core resets the lane equilibrium by attack-ordering an enemy hero standing next
-- to the enemy creep wave (drawing the creeps' aggro) then walking back to drag
-- them onto our side. J.ShouldCreepPullLane is the TRIGGER (when to pull); it must
-- be inert unless the game is turbo AND this side carries the 'creeppull' soak
-- candidate, and it must fire ONLY on the narrow, safe, disadvantaged case:
--   FIRE     = turbo + armed, laning core, disadvantaged (zoned / wave on our
--              half), one enemy hero adjacent to the enemy creeps, and safe ->
--              returns a pull intent { enemy, retreat }.
--   NO-FIRE  = favorable/even lane, no enemy adjacent to the wave, or unsafe
--              (hurt / a second enemy = possible gank) -> nil.
--   OFF      = not turbo / not the candidate -> inert (shipped default), nil.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Build the full disadvantaged-lane scenario: our healthy laning core `bot` is
-- zoned by a lone enemy `enemy` that stands right next to the enemy creep wave
-- `creep`. Turbo + the 'creeppull' candidate armed. Tests tweak one knob each to
-- drive the NO-FIRE / OFF branches. Returns J, bot, enemy.
local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	-- The enemy laner, standing adjacent to its creep wave (both at the origin so
	-- the <= 500 aggro-redirect adjacency holds).
	local enemy = api.MakeHero('npc_dota_hero_enemy', {
		GetTeam = 3, -- TEAM_DIRE
		CanBeSeen = true,
		GetLocation = opts.enemyLoc or api.Vector(0, 0, 0),
	})

	-- A second enemy hero (only installed for the gank NO-FIRE case).
	local enemy2 = api.MakeHero('npc_dota_hero_enemy2', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(50, 0, 0),
	})

	-- The enemy lane creep wave near us.
	local creep = api.MakeUnit({
		CanBeSeen = true, IsAlive = true, GetLocation = api.Vector(0, 0, 0),
	})

	-- [L1-DRAG] Optional melee-vs-2-ranged shape: both enemies RANGED (550),
	-- pecking from >= 600 away, with the bot recently harassed.
	if opts.melee2ranged then
		rawget(enemy,  '__spec').GetAttackRange = 550
		rawget(enemy2, '__spec').GetAttackRange = 550
		rawget(enemy,  '__spec').GetLocation = api.Vector(opts.e1dist or 700, 0, 0)
		rawget(enemy2, '__spec').GetLocation = api.Vector(opts.e2dist or 800, 100, 0)
		-- the enemy wave sits between us: creep adjacent to enemy1 (<500) so the
		-- aggro-draw target scan finds it, and within our 900 creep-scan radius
		rawget(creep, '__spec').GetLocation = api.Vector(500, 0, 0)
	end


	-- Our disadvantaged core: healthy, laning, sees the lone enemy nearby.
	local nearbyEnemies = (opts.notIsolated or opts.melee2ranged)
		and { enemy, enemy2 } or { enemy }
	local bot = api.MakeHero('npc_dota_hero_lion', {
		CanBeSeen = true,
		OriginalGetHealth = opts.botHealth or 600,
		OriginalGetMaxHealth = 600,
		WasRecentlyDamagedByAnyHero = opts.recentlyDamaged or false,
		GetNearbyHeroes = function(_, _radius, bEnemy)
			if bEnemy then return nearbyEnemies end
			return {}
		end,
		GetNearbyLaneCreeps = function(_, _radius, bEnemy)
			if bEnemy and not opts.noCreeps then return { creep } end
			return {}
		end,
		GetAssignedLane = function() return LANE_MID end,
		GetLocation = opts.melee2ranged and api.Vector(0, 0, 0)
			or api.Vector(-500, 0, 0),
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	-- Arm the gate: turbo + the 'creeppull' soak candidate on this side.
	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return id == 'creeppull' end

	-- The bot is a laning core (the helper restricts to pos 1-3). Pin it so the
	-- trigger does not depend on the role-map lookup for the mock hero.
	J.IsCore = function() return true end

	-- Disadvantage signal: zoned (not locally stronger). Favorable case flips it.
	J.WeAreStronger = function() return opts.favorable == true end

	-- Lane-front amounts: even by default (0.5/0.5) so the DISADVANTAGE must come
	-- from zoning; the favorable case makes both signals false.
	GetLaneFrontAmount = function() return 0.5 end -- luacheck: ignore

	return J, bot, enemy
end

tests['FIRE: zoned healthy core with an enemy next to the wave -> pull intent'] = function()
	local J, bot, enemy = scenario()
	local pull = J.ShouldCreepPullLane(bot)
	assert(type(pull) == 'table', 'the disadvantaged case must return a pull intent table')
	assert(pull.enemy == enemy, 'the intent must name the enemy hero to aggro-draw off')
	assert(pull.retreat ~= nil and pull.retreat.x ~= nil,
		'the intent must include a retreat point to drag the wave back to')
end

tests['NO-FIRE: favorable/even lane (locally stronger, even wave) -> nil'] = function()
	local J, bot = scenario({ favorable = true })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'a core that is not being zoned on an even lane has no reason to pull')
end

tests['NO-FIRE: no enemy adjacent to the wave -> nil'] = function()
	-- Enemy is still nearby (zones us) but stands far from the creep wave, so there
	-- is no valid hero to order-attack for the aggro-draw.
	local J, bot = scenario({ enemyLoc = api.Vector(-900, 0, 0) })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'without an enemy hero next to the creeps there is nothing to aggro-draw off')
end

tests['NO-FIRE: no enemy creeps present -> nil'] = function()
	local J, bot = scenario({ noCreeps = true })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'no enemy wave near us means no aggro to pull')
end

tests['NO-FIRE (unsafe): hurt core -> nil'] = function()
	local J, bot = scenario({ botHealth = 200 }) -- ~33% HP
	assert(J.ShouldCreepPullLane(bot) == nil,
		'a hurt core must not walk toward the enemy to pull')
end

tests['NO-FIRE (unsafe): second enemy nearby (possible gank) -> nil'] = function()
	local J, bot = scenario({ notIsolated = true })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'two enemy heroes nearby is a gank risk -> never pull into it')
end

tests['NO-FIRE (unsafe): recently damaged by a hero -> nil'] = function()
	local J, bot = scenario({ recentlyDamaged = true })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'a core just taking hero damage should not commit to a pull')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldCreepPullLane(bot) == nil,
		'normal mode must never trigger a creep pull')
end

tests['OFF: inert off the soak candidate'] = function()
	local J, bot = scenario()
	J.IsSoakCandidate = function() return false end
	assert(J.ShouldCreepPullLane(bot) == nil,
		'off the candidate side the trigger must stay inert (shipped default)')
end

tests['FIRE [L1-DRAG]: melee core pecked by 2 ranged from distance -> pull'] = function()
	-- Owner's case: melee-vs-double-ranged, harassed on cooldown, both pecking
	-- from >= 600 -- the recent-damage/single-enemy safety clauses are relaxed
	-- for exactly this shape, and being harassed is the TRIGGER.
	local J, bot, enemy = scenario({ melee2ranged = true, recentlyDamaged = true })
	local pull = J.ShouldCreepPullLane(bot)
	assert(type(pull) == 'table' and pull.enemy == enemy,
		'melee core pecked by two distant ranged laners must drag the wave back')
end

tests['NO-FIRE [L1-DRAG]: one of the two ranged is CLOSE (diving, not pecking) -> nil'] = function()
	local J, bot = scenario({ melee2ranged = true, recentlyDamaged = true, e1dist = 400 })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'an enemy inside 600 is a dive -- normal safety rules, never pull into it')
end

tests['NO-FIRE [L1-DRAG]: 2 ranged but NOT being harassed -> nil (old gank rule holds)'] = function()
	local J, bot = scenario({ melee2ranged = true, recentlyDamaged = false })
	assert(J.ShouldCreepPullLane(bot) == nil,
		'without the harass trigger, two nearby enemies still mean gank risk -> no pull')
end

return tests
