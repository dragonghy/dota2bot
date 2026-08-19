-- [L1-XPSOAK / LANING_PLAYBOOK] Extreme-disadvantage XP-soak contract for
-- J.ShouldXpSoakLane: a solo laning core zoned by >=2 enemies whose castable
-- burst makes contesting lethal holds a spot at the lane edge (step toward our
-- fountain), soaking XP without feeding. Owner: "保持在对方技能范围之外,吃一点
-- 经验,保证自己不死". The corrected lf_recover: AT the lane, never jungle.
--
--   FIRE     = turbo + 'l1xpsoak', laning core, >=2 enemies within 1200, no
--              healthy ally within 1400, their burst >= 75% of my hp
--              -> returns a fountain-ward step position.
--   NO-FIRE  = only one enemy / an ally close / contest not provably lethal /
--              not a core -> nil (keep laning normally).
--   OFF      = not turbo / candidate off -> nil.
--
-- [redesign 20260819] Two A1-deferred pieces now covered below too:
--   ABSOLUTE ANCHOR = the hold point is computed ONCE on entry and cached
--              on the bot (bot.l1xpsoakAnchor); later calls while still
--              zoned return the SAME point even if the bot has moved, never
--              a fresh "current position + 420u" step (the old death-march).
--   EXIT HYSTERESIS = once anchored, a borderline drop in burst (still
--              >=40% hp) or the enemy count dipping to 1 does NOT release
--              the stance; only a healthy ally, 0 enemies within 1200, or
--              burst <40% hp clears it.
--
-- Unit scenarios drive the decision boundary; the REAL zoned frame
-- (f_231411_ck_zoned: CK 126/1068 hp, Lina 1052 + Tide 584, no ally) pins the
-- geometry both ways -- see the fixture cases at the bottom.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')
local fixture = require('mock.replay_fixture')

local tests = {}

local function scenario(opts)
	opts = opts or {}
	api.reset_modules()

	local e1 = api.MakeHero('npc_dota_hero_lina', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(800, 0, 0),
		GetEstimatedDamageToTarget = opts.burst1 or 300,
	})
	local e2 = api.MakeHero('npc_dota_hero_tidehunter', {
		GetTeam = 3, CanBeSeen = true, GetLocation = api.Vector(900, 200, 0),
		GetEstimatedDamageToTarget = opts.burst2 or 300,
	})
	local ally = api.MakeHero('npc_dota_hero_crystal_maiden', {
		GetTeam = 2, CanBeSeen = true, GetLocation = api.Vector(-300, 0, 0),
		GetHealth = 500, OriginalGetHealth = 500, OriginalGetMaxHealth = 600,
	})

	local enemies = opts.oneEnemy and { e1 } or { e1, e2 }
	local bot = api.MakeHero('npc_dota_hero_chaos_knight', {
		CanBeSeen = true, GetLocation = api.Vector(0, 0, 0),
		GetHealth = opts.botHealth or 300,
		OriginalGetHealth = opts.botHealth or 300, OriginalGetMaxHealth = 1000,
		GetNearbyHeroes = function(_, _radius, bEnemy)
			if bEnemy then return enemies end
			if opts.allyNear then return { ally } end
			return {}
		end,
	})
	api.install({ bot = bot })
	local J = require(GetScriptDirectory() .. '/FunLib/jmz_func')

	GetGameMode = function() return GAMEMODE_TURBO end -- luacheck: ignore
	J.IsSoakCandidate = function(id) return id == 'l1xpsoak' end
	J.IsInLaningPhase = function() return true end
	J.IsCore = function() return opts.notCore ~= true end
	-- our fountain is at (-6000, 0): the soak step must go that way (negative x)
	J.GetTeamFountain = function() return api.Vector(-6000, 0, 0) end
	-- Past the early exemption window by default (A1 mechanism 20260731).
	DotaTime = function() return opts.time or 180 end -- luacheck: ignore

	return J, bot
end

tests['NO-FIRE (A1 exemption): the first 90s are normal lane spacing, never panic'] = function()
	local J, bot = scenario({ time = 48 })
	assert(J.ShouldXpSoakLane(bot) == nil,
		'142838 sniper at 0:48: an ordinary 1v2 open is not the extreme-disadvantage state')
end

tests['NO-FIRE (A1 exemption): above 85% HP the panic rule stays quiet'] = function()
	local J, bot = scenario()
	-- J.GetHP for allies reads OriginalGetHealth/OriginalGetMaxHealth
	-- (scenario max = 1000): set 950 = 95%.
	local sp = rawget(bot, '__spec')
	sp.GetHealth = 950
	sp.OriginalGetHealth = 950
	assert(J.ShouldXpSoakLane(bot) == nil,
		'144711 medusa entered the soak at 100% HP and death-marched -- healthy heroes lane normally')
end

tests['FIRE: solo core, 2 zoners, lethal contest (600 vs 300hp) -> fountain-ward step'] = function()
	local J, bot = scenario()
	local v = J.ShouldXpSoakLane(bot)
	assert(v ~= nil, 'the zoned-alone-lethal case must return a soak position')
	assert(v.x < 0, 'the hold point must step TOWARD our fountain (x<0), never forward/jungle')
end

tests['NO-FIRE: only one enemy -> nil (1v1 is a tradeable lane, not a zone)'] = function()
	local J, bot = scenario({ oneEnemy = true })
	assert(J.ShouldXpSoakLane(bot) == nil,
		'one zoner is not the extreme-disadvantage state; normal trade rules apply')
end

tests['NO-FIRE: healthy ally within reach -> nil (trade/kite rules own that case)'] = function()
	local J, bot = scenario({ allyNear = true })
	assert(J.ShouldXpSoakLane(bot) == nil,
		'with a support nearby the lane is contestable -- L1-TRADE/l1kite territory')
end

tests['NO-FIRE: contest not provably lethal (weak/spent enemies) -> nil'] = function()
	local J, bot = scenario({ burst1 = 80, burst2 = 60, botHealth = 800 })
	assert(J.ShouldXpSoakLane(bot) == nil,
		'a healthy core facing two spent enemies keeps laning -- no over-cowardice')
end

tests['NO-FIRE: not a core -> nil'] = function()
	local J, bot = scenario({ notCore = true })
	assert(J.ShouldXpSoakLane(bot) == nil,
		'XPSOAK is the pos-1-3 survival stance; supports have their own rules')
end

tests['OFF: inert in normal (non-turbo) mode'] = function()
	local J, bot = scenario()
	GetGameMode = function() return 1 end -- luacheck: ignore
	assert(J.ShouldXpSoakLane(bot) == nil, 'normal mode must never trigger the stance')
end

tests['OFF: inert off the soak candidate'] = function()
	local J, bot = scenario()
	J.IsSoakCandidate = function() return false end
	assert(J.ShouldXpSoakLane(bot) == nil, 'off the candidate the stance stays inert')
end

-- ---- real-frame cases (f_231411_ck_zoned: CK 126/1068, Lina 1052 + Tide 584,
-- ---- no healthy ally within 1400, laning time 3:12) ----

local function arm_fx(J, bot)
	J.IsSoakCandidate = function(id) return id == 'l1xpsoak' end
	J.IsInLaningPhase = function() return true end
	J.IsCore = function(u) return u == bot end
end

tests['REAL FRAME no-overfire: avoidance succeeded (observed poke 80 < bar 94) -> nil'] = function()
	-- Ground truth on this frame is LOW damage precisely because CK was already
	-- avoiding successfully -- the stance must NOT fire off pure observed poke.
	local J, bot = fixture.load('tests/fixtures/f_231411_ck_zoned.lua')
	arm_fx(J, bot)
	assert(J.ShouldXpSoakLane(bot) == nil,
		'a frame where avoidance already works must not trigger (no double-cowardice)')
end

tests['REAL FRAME geometry: with engine-grade estimates the zoned stance fires'] = function()
	-- The observed burst understates what Lina/Tide COULD cast (the
	-- counterfactual problem); inject engine-style castable estimates (~lvl-4
	-- Lina kit ≈ 310) onto the two real zoners and verify the REAL geometry
	-- (2 enemies in range, genuinely alone) drives the stance.
	local J, bot, heroes = fixture.load('tests/fixtures/f_231411_ck_zoned.lua')
	arm_fx(J, bot)
	rawget(heroes['npc_dota_hero_lina'], '__spec').GetEstimatedDamageToTarget = 310
	rawget(heroes['npc_dota_hero_tidehunter'], '__spec').GetEstimatedDamageToTarget = 310
	local v = J.ShouldXpSoakLane(bot)
	assert(v ~= nil, 'the real zoned-alone geometry + lethal estimates must fire the stance')
end

-- ---- redesign 20260819: absolute anchor + exit hysteresis, real frame ----

local function fire_real_frame()
	local J, bot, heroes = fixture.load('tests/fixtures/f_231411_ck_zoned.lua')
	arm_fx(J, bot)
	rawget(heroes['npc_dota_hero_lina'], '__spec').GetEstimatedDamageToTarget = 310
	rawget(heroes['npc_dota_hero_tidehunter'], '__spec').GetEstimatedDamageToTarget = 310
	return J, bot, heroes
end

tests['ABSOLUTE ANCHOR: the cached hold point does not drift if the bot moves while still zoned'] = function()
	local J, bot = fire_real_frame()
	local v1 = J.ShouldXpSoakLane(bot)
	assert(v1 ~= nil, 'setup: must fire and anchor on the real zoned frame')

	-- The bot stepped a little since the last frame (still well within 1200
	-- of both zoners, still outside 1400 of the nearest ally -- geometry
	-- unaffected). The OLD code recomputed "current position + 420u toward
	-- fountain" from this NEW location on every call, which death-marches
	-- (144711 medusa).
	rawget(bot, '__spec').GetLocation = api.Vector(v1.x - 100, v1.y - 50, 0)
	local v2 = J.ShouldXpSoakLane(bot)
	assert(v2 ~= nil, 'still zoned next frame -> the stance must still hold')
	assert(v2.x == v1.x and v2.y == v1.y,
		"the hold point must be the CACHED entry anchor, not recomputed from the bot's new position")
end

tests['EXIT HYSTERESIS: a borderline burst drop (still >=40% hp) does not release the anchor'] = function()
	local J, bot, heroes = fire_real_frame()
	local v1 = J.ShouldXpSoakLane(bot)
	assert(v1 ~= nil, 'setup: must fire and anchor on the real zoned frame')

	-- CK hp = 126: entry bar was 75% = 94.5, exit bar is 40% = 50.4 -- land
	-- the combined incoming estimate in between (70).
	rawget(heroes['npc_dota_hero_lina'], '__spec').GetEstimatedDamageToTarget = 40
	rawget(heroes['npc_dota_hero_tidehunter'], '__spec').GetEstimatedDamageToTarget = 30
	local v2 = J.ShouldXpSoakLane(bot)
	assert(v2 ~= nil, 'a borderline cooldown must not flip the stance off mid-hold')
	assert(v2.x == v1.x and v2.y == v1.y, 'the held anchor must be unchanged')
end

tests['EXIT: burst clearly below the hysteresis floor (<40% hp) releases the anchor'] = function()
	local J, bot, heroes = fire_real_frame()
	assert(J.ShouldXpSoakLane(bot) ~= nil, 'setup: must fire and anchor on the real zoned frame')

	rawget(heroes['npc_dota_hero_lina'], '__spec').GetEstimatedDamageToTarget = 10
	rawget(heroes['npc_dota_hero_tidehunter'], '__spec').GetEstimatedDamageToTarget = 10
	assert(J.ShouldXpSoakLane(bot) == nil,
		'threat clearly gone (<40% hp) -> the stance must release, not hold forever')
end

tests['EXIT: a healthy ally arriving releases an anchored stance immediately'] = function()
	local J, bot, heroes = fire_real_frame()
	assert(J.ShouldXpSoakLane(bot) ~= nil, 'setup: must fire and anchor on the real zoned frame')

	-- Skywrath (same team, 92% hp) sits just outside 1400 in the real frame
	-- (~1428, why the stance could fire alone); pull it into range.
	rawget(heroes['npc_dota_hero_skywrath_mage'], '__spec').GetLocation =
		api.Vector(4900, -4600, 0)
	assert(J.ShouldXpSoakLane(bot) == nil,
		'a healthy ally arriving must release the stance even though the burst is still lethal')
end

return tests
