-- [L5-COMBO / LANING_PLAYBOOK] Support kill-call contract for
-- J.ShouldSupportComboKill: the enemy 4 walked too deep (an allied CORE is on
-- it) and our combined castable burst kills -> the support joins the 2-man
-- focus. Owner's inverse-risk rule makes the self-gates STRICTER than the core
-- version (l1trade): their burst vs me < 60% of my hp (not 75%), and NO second
-- enemy within 700 of me (their 3+4 both turning = the squishier 5 dies first).
--
--   FIRE     = turbo + 'l5combo', laning support, core on the target, lethal
--              combined burst, both self-gates pass -> returns the target.
--   NO-FIRE  = no core on it / burst not lethal / 60% bar tripped / second
--              enemy close / bot is a core -> nil.
--   OFF      = not turbo / candidate off -> nil.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	-- The too-deep enemy 4 (the kill target), 400 from me.
	local target = api.MakeHero('npc_dota_hero_vengefulspirit', {
		GetTeam = 3, CanBeSeen = true,
		GetLocation = api.Vector(400, 0, 0),
		GetHealth = 300, OriginalGetHealth = 300, OriginalGetMaxHealth = 700,
		GetHealthRegen = 2,
		GetEstimatedDamageToTarget = opts.targetBurst or 100,
	})
	-- Their 3 (only present for the second-enemy guard case), 600 from me.
	local enemy2 = api.MakeHero('npc_dota_hero_tidehunter', {
		GetTeam = 3, CanBeSeen = true,
		GetLocation = api.Vector(600, 100, 0),
		GetEstimatedDamageToTarget = 100,
	})
	-- Our core, right on the target (the 2-man focus is available).
	local core = api.MakeHero('npc_dota_hero_juggernaut', {
		GetTeam = 2, CanBeSeen = true,
		GetLocation = api.Vector(500, 0, 0),
		GetHealth = 700, OriginalGetHealth = 700, OriginalGetMaxHealth = 800,
		GetEstimatedDamageToTarget = opts.coreBurst or 250,
	})

	local enemies = opts.secondEnemy and { target, enemy2 } or { target }
	local bot = api.MakeHero('npc_dota_hero_crystal_maiden', {
		CanBeSeen = true,
		GetLocation = api.Vector(0, 0, 0),
		GetHealth = 500, OriginalGetHealth = 500, OriginalGetMaxHealth = 500,
		GetEstimatedDamageToTarget = opts.myBurst or 150,
		GetNearbyHeroes = function(_, _r, bEnemy)
			if bEnemy then return enemies end
			return { core }
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return id == 'l5combo' end
	J.IsInLaningPhase = function() return true end
	J.IsCore = function(u) return u == core or (opts.botIsCore and u == bot) end
	J.GetAlliesNearLoc = function()
		if opts.noCoreOnTarget then return { bot } end
		return { bot, core }
	end

	return J, bot, target
end

tests['FIRE: core on the deep enemy, lethal 150+250 vs 308, self-safe -> target'] = function()
	local J, bot, target = scenario()
	assert(J.ShouldSupportComboKill(bot) == target,
		'the 2-man kill window on a too-deep enemy 4 must be converted')
end

tests['NO-FIRE (depth gate, analyst 20260723): target deep past the midline -> nil'] = function()
	-- The 26f batch showed the combo firing 3000u past the midline -- a tower
	-- chase, not a "too deep on OUR half" punish. Team-dependent ancients put
	-- the target 3000 CLOSER to the enemy ancient than to ours -> skip.
	local J, bot, target = scenario()
	GetAncient = function(team) -- luacheck: ignore
		if team == GetTeam() then
			return api.MakeUnit({ GetLocation = api.Vector(400 + 5000, 0, 0) })
		end
		return api.MakeUnit({ GetLocation = api.Vector(400 - 2000, 0, 0) })
	end
	assert(J.ShouldSupportComboKill(bot) == nil,
		'a kill 3000u past the midline is a dive, not a too-deep punish')
	-- Same target on OUR side of the midline: the combo fires as before.
	GetAncient = function(team) -- luacheck: ignore
		if team == GetTeam() then
			return api.MakeUnit({ GetLocation = api.Vector(400 - 2000, 0, 0) })
		end
		return api.MakeUnit({ GetLocation = api.Vector(400 + 5000, 0, 0) })
	end
	assert(J.ShouldSupportComboKill(bot) == target,
		'on our half the punish is exactly the rule -- must still fire')
end

tests['NO-FIRE: no allied core on the target -> nil (never a solo support dive)'] = function()
	local J, bot = scenario({ noCoreOnTarget = true })
	assert(J.ShouldSupportComboKill(bot) == nil,
		'without the core on it this is a solo dive by the squishiest hero -- never')
end

tests['NO-FIRE: combined burst not lethal -> nil'] = function()
	local J, bot = scenario({ myBurst = 50, coreBurst = 100 })
	assert(J.ShouldSupportComboKill(bot) == nil,
		'150 total vs 308 needed is not a kill')
end

tests['NO-FIRE (strict 60% bar): their burst vs me at 65% of my hp -> nil'] = function()
	-- 325 incoming vs 500 hp = 65%: passes the core rule (75%) but MUST trip
	-- the stricter support bar (60%).
	local J, bot = scenario({ targetBurst = 325 })
	assert(J.ShouldSupportComboKill(bot) == nil,
		'the support self-risk bar is 60%, stricter than the core version')
end

tests['NO-FIRE: a second enemy within 700 of me -> nil (their 3+4 turn, I die first)'] = function()
	local J, bot = scenario({ secondEnemy = true })
	assert(J.ShouldSupportComboKill(bot) == nil,
		'two enemy laners near the squishy 5 = never jump, whatever the math says')
end

tests['NO-FIRE: bot is a core -> nil (core version is l1trade)'] = function()
	local J, bot = scenario({ botIsCore = true })
	assert(J.ShouldSupportComboKill(bot) == nil,
		'L5-COMBO is the pos-4/5 rule; cores initiate through l1trade')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldSupportComboKill(bot) == nil, 'normal mode never triggers')
end

tests['OFF: inert off the soak candidate'] = function()
	local J, bot = scenario()
	J.IsSoakCandidate = function() return false end
	assert(J.ShouldSupportComboKill(bot) == nil, 'inert off the l5combo candidate')
end

return tests
