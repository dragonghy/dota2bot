-- [ccburst / obs 20260722] CC-aware burst window for the promoted lanesurv
-- guard. Post-promote replay review: focus deaths moved past the midline and
-- the killers became hard-CC laners (Shadow Shaman x4 shackles, DK stun) -- a
-- CC'd target eats 4-6s of damage, so the flat 3s estimate systematically
-- underestimates burst from an enemy whose hard CC is READY. Under 'ccburst'
-- such enemies are estimated over 5s. Off the candidate the window stays 3.0
-- everywhere (promoted behavior byte-identical).
--
-- The enemy's GetEstimatedDamageToTarget is duration-sensitive in these tests
-- (dmg = 100/s), so the 3s-vs-5s window choice is exactly what's asserted:
--   bot hp 500, bar (no peel) = 375. 3s -> 300 < 375 (stay); 5s -> 500 (flee).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	local cc = api.MakeAbility(opts.abilityName or 'shadow_shaman_shackles', {
		GetLevel = opts.abilityLevel or 1,
		IsFullyCastable = opts.ccReady ~= false,
		IsPassive = false,
		GetCastRange = opts.ccRange or 400,  -- shackles' real cast range
	})
	local enemy = api.MakeHero('npc_dota_hero_shadow_shaman', {
		GetTeam = 3, CanBeSeen = true,
		-- default 600 out: inside shackles' 400+250 delivery reach
		GetLocation = api.Vector(opts.enemyDist or 600, 0, 0),
		GetAbilityInSlot = function(_, slot) if slot == 0 then return cc end return nil end,
		-- duration-sensitive: 100 damage per second of window
		GetEstimatedDamageToTarget = function(_, _cur, _t, dur) return dur * 100 end,
	})
	local bot = api.MakeHero('npc_dota_hero_zuus', {
		CanBeSeen = true, GetLocation = api.Vector(0, 0, 0),
		GetHealth = 500, OriginalGetHealth = 500, OriginalGetMaxHealth = 500,
		GetNearbyHeroes = function(_, _r, bEnemy)
			if bEnemy then return { enemy } end
			return {}  -- no peel ally -> 75% bar = 375
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return opts.armed ~= false and id == 'ccburst' end
	J.IsInLaningPhase = function() return true end
	return J, bot, enemy
end

tests['FIRE: ccburst armed + SS shackles ready -> 5s window (500 >= 375) -> flee'] = function()
	local J, bot = scenario()
	assert(J.ShouldRetreatLaneBurst(bot) == true,
		'a ready hard-CC extends the effective burst window; 5s read must trip the guard')
end

tests['NO-FIRE (promoted baseline): ccburst OFF -> 3s window (300 < 375) -> stay'] = function()
	local J, bot = scenario({ armed = false })
	assert(J.ShouldRetreatLaneBurst(bot) == false,
		'off the candidate the promoted 3s behavior is byte-identical (no over-fleeing)')
end

tests['NO-FIRE: armed but the CC is on cooldown -> 3s window -> stay'] = function()
	local J, bot = scenario({ ccReady = false })
	assert(J.ShouldRetreatLaneBurst(bot) == false,
		'a spent shackle cannot lock me; the flat window applies')
end

tests['NO-FIRE: armed but the CC is unleveled (level 0) -> 3s window -> stay'] = function()
	local J, bot = scenario({ abilityLevel = 0 })
	assert(J.ShouldRetreatLaneBurst(bot) == false,
		'an unskilled ability is not a threat')
end

tests['NO-FIRE: armed but the ability is not in the hard-CC table -> 3s window'] = function()
	local J, bot = scenario({ abilityName = 'lich_frost_nova' })
	assert(J.ShouldRetreatLaneBurst(bot) == false,
		'only curated hard-CC (stun/hex/shackle) extends the window; a slow does not')
end

tests['NARROWED (bisect 20260723): CC holder OUT of delivery reach -> 3s -> stay'] = function()
	-- The range-blind first cut is the prime single-id suspect of the
	-- passive-stack death signature (full-HP bots fleeing routine lanes).
	-- Shackles reach = 400 cast + 250 buffer = 650; an SS at 1000 cannot
	-- lock me before I step away, so the flat 3s window must apply.
	local J, bot = scenario({ enemyDist = 1000 })
	assert(J.ShouldRetreatLaneBurst(bot) == false,
		'a ready CC the holder cannot deliver must not widen the burst window')
end

tests['predicate: HasReadyHardCc true/false tracks readiness'] = function()
	local J, _, enemy = scenario()
	assert(J.HasReadyHardCc(enemy) == true, 'ready leveled shackles -> true')
	local J2, _, enemy2 = scenario({ ccReady = false })
	assert(J2.HasReadyHardCc(enemy2) == false, 'on cooldown -> false')
end

return tests
