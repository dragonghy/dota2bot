-- [L1-TRADE / LANING_PLAYBOOK] Lane-kill initiation contract for
-- J.ShouldInitiateLaneKill: a laning CORE with a healthy backing ally converts
-- an open lethal kill window (our combined castable burst kills the lane enemy)
-- -- but ONLY when the self-risk gate passes (their castable burst does not
-- threaten me). Owner's model: "辅助消耗到位、两人加起来能击杀 -> 主动先手";
-- inverse guard "别上一个会先死的换".
--
--   FIRE     = turbo + 'l1trade', laning core, backed, target reachable, our
--              burst lethal, my incoming safe -> returns the target.
--   NO-FIRE  = burst not lethal / no backing ally / their burst threatens me /
--              not a core -> nil.
--   OFF      = not turbo / candidate off -> nil (shipped default inert).

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Scenario: our core `bot` + healthy support ally vs one low enemy laner.
-- Damage numbers are driven through GetEstimatedDamageToTarget on each unit:
-- ours -> lethal vs the 300-hp target by default; theirs -> weak vs us.
-- Knobs flip exactly one condition each.
local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	local enemy = api.MakeHero('npc_dota_hero_sven', {
		GetTeam = 3, CanBeSeen = true,
		GetLocation = api.Vector(400, 0, 0),
		GetHealth = 300, OriginalGetHealth = 300, OriginalGetMaxHealth = 900,
		GetHealthRegen = 2,
		-- what THEY can cast at me right now
		GetEstimatedDamageToTarget = opts.enemyBurst or 150,
	})

	local ally = api.MakeHero('npc_dota_hero_crystal_maiden', {
		GetTeam = 2, CanBeSeen = true,
		GetLocation = api.Vector(200, 100, 0),
		GetHealth = opts.allyHealth or 500,
		OriginalGetHealth = opts.allyHealth or 500, OriginalGetMaxHealth = 600,
		GetEstimatedDamageToTarget = opts.allyBurst or 200,
	})

	local bot = api.MakeHero('npc_dota_hero_juggernaut', {
		CanBeSeen = true,
		GetLocation = api.Vector(0, 0, 0),
		GetHealth = 800, OriginalGetHealth = 800, OriginalGetMaxHealth = 800,
		GetEstimatedDamageToTarget = opts.myBurst or 200,
		GetNearbyHeroes = function(_, _radius, bEnemy)
			if bEnemy then return { enemy } end
			if opts.noAlly then return {} end
			return { ally }
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return id == 'l1trade' end
	J.IsInLaningPhase = function() return true end
	J.IsCore = function() return opts.notCore ~= true end
	-- allies near the TARGET's location = me + the support (unless noAlly)
	J.GetAlliesNearLoc = function()
		if opts.noAlly then return { bot } end
		return { bot, ally }
	end

	return J, bot, enemy
end

tests['FIRE: backed core, lethal combined burst (400 vs 308), safe -> target'] = function()
	local J, bot, enemy = scenario()
	assert(J.ShouldInitiateLaneKill(bot) == enemy,
		'combined 200+200 castable burst vs 300hp+8 regen target must convert the kill')
end

tests['NO-FIRE: combined burst not lethal -> nil'] = function()
	local J, bot = scenario({ myBurst = 100, allyBurst = 100 })
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'200 total vs 308 needed is not a kill -- do not start a losing trade')
end

tests['NO-FIRE: no backing ally -> nil'] = function()
	local J, bot = scenario({ noAlly = true })
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'the initiate rule requires the support beside me (solo initiation is L5-COMBO risk)')
end

tests['NO-FIRE: backing ally too hurt (<40%) -> nil'] = function()
	local J, bot = scenario({ allyHealth = 150 })
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'a 25%-HP support cannot back a trade -- treat as unbacked')
end

tests['NO-FIRE (self-risk): their castable burst threatens me -> nil'] = function()
	local J, bot = scenario({ enemyBurst = 700 }) -- >= 75% of my 800 hp
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'never initiate a trade where I am the one who dies first (owner: 你更脆就别上)')
end

tests['NO-FIRE: not a core -> nil (support version is L5-COMBO, later)'] = function()
	local J, bot = scenario({ notCore = true })
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'L1-TRADE is the core initiation rule; supports get their own gated rule')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'normal mode must never trigger the initiation')
end

tests['OFF: inert off the soak candidate'] = function()
	local J, bot = scenario()
	J.IsSoakCandidate = function() return false end
	assert(J.ShouldInitiateLaneKill(bot) == nil,
		'off the l1trade candidate the trigger stays inert (shipped default)')
end

tests['ANTI-OSC: no re-initiation inside a fresh kite window (watched 181046 CK)'] = function()
    local J, bot = scenario()
    DotaTime = function() return 100 end -- luacheck: ignore
    bot.laneKiteUntil = 101.5  -- we just decided to kite; no commit flapping
    assert(J.ShouldInitiateLaneKill(bot) == nil,
        'kite-lock: a fresh kite decision suppresses re-initiation')
    bot.laneKiteUntil = 99
    assert(J.ShouldInitiateLaneKill(bot) ~= nil,
        'after the kite window the initiation works as before')
end

return tests
