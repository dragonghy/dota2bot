-- [GH #11] Body-block / harass (卡身位) trigger + gating contract. The advantaged
-- mirror of creep-pull: a WINNING laning core steps up and auto-attacks the single
-- enemy laner when the trade is clearly winnable. J.ShouldBodyBlockHarass is the
-- TRIGGER (whom to harass, or nil); it must be inert unless the game is turbo AND
-- this side carries the 'bodyblock' soak candidate, and it must fire ONLY on the
-- narrow, safe, advantaged case:
--   FIRE     = turbo + armed, laning core, healthy, exactly one enemy laner in
--              range, we are locally stronger AND the fight is winnable -> returns
--              the enemy hero to harass.
--   NO-FIRE  = not stronger, or the fight is not winnable, or the enemy is out of
--              stepping range -> nil (fall through to plain last-hit).
--   NO-FIRE  = unsafe (hurt / just took hero damage / a second enemy = gank) -> nil.
--   OFF      = not turbo / not the candidate -> inert (shipped default), nil.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Build the advantaged-lane scenario: our healthy laning core `bot` faces a lone
-- enemy laner `enemy` within stepping range. Turbo + the 'bodyblock' candidate
-- armed, we are locally stronger, and the fight is winnable. Tests tweak one knob
-- each to drive the NO-FIRE / OFF branches. Returns J, bot, enemy.
local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	-- The lone enemy laner, in stepping range in front of us.
	local enemy = api.MakeHero('npc_dota_hero_enemy', {
		GetTeam = 3, -- TEAM_DIRE
		CanBeSeen = true,
		GetLocation = opts.enemyLoc or api.Vector(300, 0, 0),
	})

	-- A second enemy hero (only installed for the gank NO-FIRE case).
	local enemy2 = api.MakeHero('npc_dota_hero_enemy2', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(350, 0, 0),
	})

	local nearbyEnemies = opts.notIsolated and { enemy, enemy2 } or { enemy }
	local bot = api.MakeHero('npc_dota_hero_lion', {
		CanBeSeen = true,
		OriginalGetHealth = opts.botHealth or 600,
		OriginalGetMaxHealth = 600,
		WasRecentlyDamagedByAnyHero = opts.recentlyDamaged or false,
		GetNearbyHeroes = function(_, _radius, bEnemy)
			if bEnemy then return nearbyEnemies end
			return {}
		end,
		GetLocation = api.Vector(0, 0, 0),
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	-- Arm the gate: turbo + the 'bodyblock' soak candidate on this side.
	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return id == 'bodyblock' end

	-- The bot is a laning core (helper restricts to pos 1-3). Pin it.
	J.IsCore = function() return true end

	-- Advantage signals, both stubbed so the test isolates the trigger logic from
	-- the (heavily game-state dependent) power-balance internals. Defaults ON.
	J.WeAreStronger = function() return opts.notStronger ~= true end
	J.SafeToCommitFight = function() return opts.notWinnable ~= true end

	return J, bot, enemy
end

tests['FIRE: advantaged healthy core with a lone winnable enemy -> harass target'] = function()
	local J, bot, enemy = scenario()
	local target = J.ShouldBodyBlockHarass(bot)
	assert(target == enemy, 'the advantaged case must return the enemy hero to harass')
end

tests['NO-FIRE: not locally stronger -> nil'] = function()
	local J, bot = scenario({ notStronger = true })
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'without a local power advantage we must not step up')
end

tests['NO-FIRE: fight not winnable (SafeToCommitFight false) -> nil'] = function()
	local J, bot = scenario({ notWinnable = true })
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'the kill-line gate must block a harass that cannot win the trade')
end

tests['NO-FIRE: enemy out of stepping range -> nil'] = function()
	local J, bot = scenario({ enemyLoc = api.Vector(900, 0, 0) })
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'a far enemy is not a body-block opportunity, only a walk into fog')
end

tests['NO-FIRE (unsafe): hurt core -> nil'] = function()
	local J, bot = scenario({ botHealth = 300 }) -- 50% HP, below the 60% floor
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'a hurt core must not step up even on a "won" lane')
end

tests['NO-FIRE (unsafe): recently damaged by a hero -> nil'] = function()
	local J, bot = scenario({ recentlyDamaged = true })
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'a core just taking hero damage should not commit to a step-up')
end

tests['NO-FIRE (unsafe): second enemy nearby (possible gank) -> nil'] = function()
	local J, bot = scenario({ notIsolated = true })
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'two enemy heroes present is a gank risk -> never step up')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'normal mode must never trigger a body-block harass')
end

tests['OFF: inert off the soak candidate'] = function()
	local J, bot = scenario()
	J.IsSoakCandidate = function() return false end
	assert(J.ShouldBodyBlockHarass(bot) == nil,
		'off the candidate side the trigger must stay inert (shipped default)')
end

return tests
