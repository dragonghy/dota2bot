-- [tpwatch / wave12 dossier #24] Abandon-the-eaten-channel contract.
-- Dossier case: necro started a TP channel at 100% HP (tpsafe2 passed --
-- no interruptor in range at the cast instant), viper then auto-attacked
-- him for 74% of his HP across the 5.5s channel, and he died 1.3s after
-- landing. J.ShouldAbandonTpChannel must fire once >=30% of max HP is lost
-- since the channel began, under fresh hero damage, while channeling.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local tests = {}

local function fresh(opts)
	opts = opts or {}
	api.reset_modules()
	local channeling = opts.channeling ~= false
	local bot = api.MakeHero('npc_dota_hero_necrolyte', {
		CanBeSeen = true,
		GetHealth = opts.hp or 1000,
		OriginalGetHealth = opts.hp or 1000,
		GetMaxHealth = 1000, OriginalGetMaxHealth = 1000,
		HasModifier = function(_, m)
			return m == 'modifier_teleporting' and channeling
		end,
		WasRecentlyDamagedByAnyHero = opts.damaged ~= false,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')
	GetGameMode = function() return opts.turbo == false and 1 or GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id)
		return opts.off ~= true and id == 'tpwatch'
	end
	return J, bot
end

tests['FIRE: channel eaten for 35% max HP under fire -> abandon'] = function()
	local J, bot = fresh()
	assert(J.ShouldAbandonTpChannel(bot) == false, 'first frame stamps 1000')
	local sp = rawget(bot, '__spec')
	sp.GetHealth = 650
	sp.OriginalGetHealth = 650
	assert(J.ShouldAbandonTpChannel(bot) == true,
		'the #24 pattern: keeping this channel spends the scroll AND the health')
end

tests['NO-FIRE: light chip (10%) keeps the channel'] = function()
	local J, bot = fresh()
	J.ShouldAbandonTpChannel(bot)
	local sp = rawget(bot, '__spec')
	sp.GetHealth = 900
	sp.OriginalGetHealth = 900
	assert(J.ShouldAbandonTpChannel(bot) == false,
		'a poke is not a reason to waste a nearly-done channel')
end

tests['NO-FIRE: same HP loss but no fresh hero damage (DOT wore off) -> keep'] = function()
	local J, bot = fresh()
	J.ShouldAbandonTpChannel(bot)
	local sp = rawget(bot, '__spec')
	sp.GetHealth = 600
	sp.OriginalGetHealth = 600
	sp.WasRecentlyDamagedByAnyHero = false
	assert(J.ShouldAbandonTpChannel(bot) == false,
		'nobody is actively eating the channel any more -- finish it')
end

tests['RESET: not channeling clears the stamp (and never fires)'] = function()
	local J, bot = fresh({ channeling = false })
	assert(J.ShouldAbandonTpChannel(bot) == false, 'not channeling')
	assert(bot.tpChannelStartHealth == nil, 'stamp must clear off-channel')
end

tests['OFF: candidate off / normal mode -> inert (stamp still maintained)'] = function()
	local J, bot = fresh({ off = true })
	J.ShouldAbandonTpChannel(bot)
	local sp = rawget(bot, '__spec')
	sp.GetHealth = 500
	sp.OriginalGetHealth = 500
	assert(J.ShouldAbandonTpChannel(bot) == false, 'candidate off -> inert')
	local J2, bot2 = fresh({ turbo = false })
	J2.ShouldAbandonTpChannel(bot2)
	local sp2 = rawget(bot2, '__spec')
	sp2.GetHealth = 500
	sp2.OriginalGetHealth = 500
	assert(J2.ShouldAbandonTpChannel(bot2) == false, 'normal mode -> inert')
end

return tests
