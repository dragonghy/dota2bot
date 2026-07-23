-- [TP audit fix C / tpcommit] Landing commitment for the gated response TPs.
-- Owner-watched pathology (tp_audit_20260723): responders TP in on a correct
-- trigger, then lane assignment reclaims them -- they land, attack nothing,
-- and walk home (game 233217 ~1:00: five TPs answered, zero attacks thrown).
-- The item-usage response branches stamp bot.tpRespondLoc/-Until at cast time;
-- J.GetTpCommitDefendDesire returns a defend-desire floor (0.85) for the lane
-- that was answered, for as long as the window is fresh AND somebody is still
-- visible at the trigger. Gated turbo + 'tpcommit'; inert by default.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

-- Scenario: the bot answered a trigger at (4000,0) -- the TOP lane's front is
-- 500u from it; MID/BOT fronts are far. One visible enemy stands at the
-- trigger. Knobs flip exactly one condition each.
local function fresh(opts)
	opts = opts or {}
	api.reset_modules()

	local trigger = api.Vector(4000, 0, 0)
	local enemy = api.MakeHero('npc_dota_hero_viper', {
		GetTeam = 3, CanBeSeen = true,
		GetLocation = trigger,
	})
	local bot = api.MakeHero('npc_dota_hero_sven', { CanBeSeen = true })
	api.install({ bot = bot })

	GetUnitList = function(kind) -- luacheck: ignore
		if kind == UNIT_LIST_ENEMY_HEROES and opts.noEnemy ~= true then
			return { enemy }
		end
		return {}
	end
	GetLaneFrontLocation = function(_, lane) -- luacheck: ignore
		if lane == LANE_TOP then return api.Vector(4000, 500, 0) end
		return api.Vector(-8000, -8000, 0)
	end
	GetGameMode = function() return opts.turbo == false and 1 or GAMEMODE_TURBO end -- luacheck: ignore
	DotaTime = function() return 100 end -- luacheck: ignore

	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
	J.IsSoakCandidate = function(id)
		return opts.armed ~= false and id == 'tpcommit'
	end
	if opts.stamp ~= false then
		bot.tpRespondLoc = trigger
		bot.tpRespondUntil = opts.expire or 110  -- fresh (now = 100)
	end
	return J, bot
end

tests['FIRE: fresh commitment + hot trigger -> 0.85 floor on the answered lane'] = function()
	local J, bot = fresh()
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == 0.85,
		'a responder that just answered a live trigger must stay on it')
end

tests['LANE-BINDING: the same commitment yields nothing for the other lanes'] = function()
	local J, bot = fresh()
	assert(J.GetTpCommitDefendDesire(bot, LANE_MID) == nil,
		'the floor binds to the lane whose front is at the trigger, not all lanes')
	assert(J.GetTpCommitDefendDesire(bot, LANE_BOT) == nil,
		'ditto for the third lane')
end

tests['NO-FIRE: commitment window expired -> nil'] = function()
	local J, bot = fresh({ expire = 95 })  -- now = 100 > 95
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == nil,
		'a stale stamp must not pin the bot to an old trigger forever')
end

tests['NO-FIRE: no stamp (never answered a TP) -> nil'] = function()
	local J, bot = fresh({ stamp = false })
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == nil,
		'without a response stamp there is nothing to commit to')
end

tests['NO-FIRE: trigger gone cold (no visible enemy there) -> nil'] = function()
	local J, bot = fresh({ noEnemy = true })
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == nil,
		'nobody left to engage -> release, do not stand around a cold spot')
	assert(bot.tpRespondUntil ~= nil,
		'a fog frame only skips the floor; the stamp survives (they may reappear)')
end

tests['OFF: inert off the soak candidate (shipped default)'] = function()
	local J, bot = fresh({ armed = false })
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == nil,
		'off the tpcommit candidate the floor must never fire')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = fresh({ turbo = false })
	assert(J.GetTpCommitDefendDesire(bot, LANE_TOP) == nil,
		'normal mode ships unchanged')
end

return tests
