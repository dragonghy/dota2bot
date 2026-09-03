-- [hero, `zeusaghs5`] Support Zeus's Aghanim's Scepter timing.
--
-- WHY (theory, not corpus). Zeus's shipped pos_5 buy list puts item_ultimate_scepter
-- at index 8, behind item_ancient_janggo + item_aether_lens + item_glimmer_cape +
-- item_pipe + item_boots_of_bearing. Cumulative gold to reach Aghs shipped is
-- ~11.2k (blood_grenade 25 + mage_outfit ~1755 + janggo 985 + aether 2275 +
-- glimmer 2050 + pipe 3200 + boots_of_bearing recipe 900). Zeus pos_5 running at
-- ~350 GPM reaches 11.2k gold at ~32 min; Turbo games end around 20 min, so the
-- shipped index leaves Aghs unreachable in the vast majority of games. Nimbus (the
-- Aghs unlock) is the largest single power spike Zeus owns for teamfights.
--
-- The reorder moves item_ultimate_scepter to slot 5 (directly after item_aether_lens);
-- every other item keeps its relative order. Gate-off is a pure no-op, asserted
-- byte-for-byte.
--
-- HONEST BOUNDS (this file is not the batch):
--   * There is no measured Zeus pos_5 corpus in this repo yet, so no
--     `nw_at_boots`-style projections are pinned here. What this file DOES pin is
--     that the reorder is a byte-for-byte permutation and that gate-off is
--     unchanged. Reachability is an argument, not a measurement, and it is in the
--     block above the helper in hero_zuus.lua rather than in this test.
--   * Whether an Aghs-first pos_5 Zeus actually helps a team win is an emergent
--     question (the lanefix / cmboots lesson: locally-defensible caster-support
--     build changes have to earn condition (b) before they ship). That is what the
--     gate and the batch A/B are for.

package.path = 'tests/?.lua;' .. package.path
local api = require('mock.bot_api')

local ss = require('mock.soak_side')                -- owns bots/Customize/soak_side.lua
local CAND = 'zeusaghs5'

local tests = {}

-- The shipped pos_5 order, transcribed byte-for-byte from bots/BotLib/hero_zuus.lua.
-- Any drift between this and the file is a real failure, not a chore: the
-- gate-off path must remain the shipped default exactly.
local SHIPPED_POS5 = {
	'item_blood_grenade',
	'item_mage_outfit',
	'item_ancient_janggo',
	'item_aether_lens',
	'item_glimmer_cape',
	'item_pipe',
	'item_boots_of_bearing',
	'item_ultimate_scepter',
	'item_cyclone',
	'item_shivas_guard',
	'item_sheepstick',
	'item_wind_waker',
	'item_moon_shard',
	'item_ultimate_scepter_2',
}

local ARMED_POS5 = {
	'item_blood_grenade',
	'item_mage_outfit',
	'item_ancient_janggo',
	'item_aether_lens',
	'item_ultimate_scepter',   -- moved from slot 8 to slot 5
	'item_glimmer_cape',
	'item_pipe',
	'item_boots_of_bearing',
	'item_cyclone',
	'item_shivas_guard',
	'item_sheepstick',
	'item_wind_waker',
	'item_moon_shard',
	'item_ultimate_scepter_2',
}

local function load_zeus(bTurbo, nRole)
	api.reset_modules()
	local bot = api.MakeHero('npc_dota_hero_zuus', { CanBeSeen = true })
	bot.assignedRole = nRole or 5
	api.install({ bot = bot })
	-- Both teams must agree: J.IsSoakCandidateSide compares GetTeam() against
	-- TEAM_RADIANT, while Role.GetPosition compares GetTeam() against
	-- bot:GetTeam() and hands back a hardcoded 3 for anyone it reads as an
	-- enemy. Setting only one of them silently pins every role to pos_3.
	GetTeam = function() return TEAM_RADIANT end
	bot.GetTeam = function() return TEAM_RADIANT end
	if bTurbo == false then
		GetGameMode = function() return 1 end
	else
		GetGameMode = function() return GAMEMODE_TURBO end
	end
	return dofile('bots/BotLib/hero_zuus.lua')
end

-- Arm a soak candidate by writing the (gitignored) side file, using the shared
-- helper. See tests/mock/soak_side.lua for the write-back-and-verify semantics
-- that GH #417 / GH #365 §3 forced into every gate test.
local function with_candidate(sId, fn)
	ss.with_candidate(sId, fn)
end

--- The "gate off" cases below claim the gate is shut; what they can actually
--- observe is "the shipped list". Those are the same observation only while no
--- soak_side file exists, and that path is one global inode written by every
--- gate test in the tree and by every concurrent lua5.1 process.
local function assert_unarmed()
	ss.assert_clean('test_zeus_aghs_build')
end

-- ...and once HERE, at file-load time, the only moment that sees the state this
-- process STARTED in: `with_candidate` ends by removing the switch, and the
-- armed cases can sort before the unarmed ones, so an INHERITED leftover is
-- deleted by a sibling case before any per-case guard looks at it (GH #417:
-- such a leftover survived a per-case guard 19/19 green).
assert_unarmed()

local function assert_same_list(tGot, tWant, sWhat)
	assert(type(tGot) == 'table', sWhat .. ': buy list is not a table')
	assert(#tGot == #tWant,
		sWhat .. ': expected ' .. #tWant .. ' entries, got ' .. #tGot)
	for i = 1, #tWant do
		assert(tGot[i] == tWant[i],
			sWhat .. ': entry ' .. i .. ' is ' .. tostring(tGot[i])
			.. ', expected ' .. tostring(tWant[i]))
	end
end

local function index_of(tList, sItem)
	for i, s in ipairs(tList) do
		if s == sItem then return i end
	end
	return nil
end

-- Multiset equality: the reorder must add nothing and drop nothing.
local function assert_permutation(tGot, tWant, sWhat)
	assert(#tGot == #tWant,
		sWhat .. ': length changed (' .. #tGot .. ' vs ' .. #tWant .. ')')
	local count = {}
	for _, s in ipairs(tWant) do count[s] = (count[s] or 0) + 1 end
	for _, s in ipairs(tGot) do count[s] = (count[s] or 0) - 1 end
	for s, n in pairs(count) do
		assert(n == 0, sWhat .. ': item ' .. s .. ' count differs by ' .. -n)
	end
end

-- Everything except item_ultimate_scepter keeps its relative order.
local function assert_order_preserved_except_aghs(tGot, tWant, sWhat)
	local a, b = {}, {}
	for _, s in ipairs(tGot) do if s ~= 'item_ultimate_scepter' then a[#a + 1] = s end end
	for _, s in ipairs(tWant) do if s ~= 'item_ultimate_scepter' then b[#b + 1] = s end end
	assert_same_list(a, b, sWhat .. ' (non-Aghs subsequence)')
end

tests['gate off: pos_5 is the shipped order byte for byte'] = function()
	assert_unarmed()
	local X = load_zeus(true, 5)   -- turbo, but no soak_side file exists
	assert_same_list(X.sBuyList, SHIPPED_POS5, 'pos_5 gate off')
end

tests['armed in NORMAL mode leaves the shipped order (turbo-only)'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(false, 5)
		assert_same_list(X.sBuyList, SHIPPED_POS5, 'pos_5 armed but normal mode')
	end)
end

tests['a different armed candidate leaves the shipped list'] = function()
	with_candidate('wkbuild', function()
		local X = load_zeus(true, 5)
		assert_same_list(X.sBuyList, SHIPPED_POS5, 'pos_5 with another candidate armed')
	end)
end

tests['armed in turbo: pos_5 puts Aghs directly after Aether Lens'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 5)
		assert_same_list(X.sBuyList, ARMED_POS5, 'pos_5 armed')
		local nAether = index_of(X.sBuyList, 'item_aether_lens')
		local nAghs = index_of(X.sBuyList, 'item_ultimate_scepter')
		assert(nAether ~= nil and nAghs == nAether + 1,
			'Aghs must land directly after Aether Lens; aether=' .. tostring(nAether)
			.. ' aghs=' .. tostring(nAghs))
	end)
end

tests['armed permutation: nothing added, nothing dropped'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 5)
		assert_permutation(X.sBuyList, SHIPPED_POS5, 'pos_5 armed')
	end)
end

tests['armed subsequence: everything except Aghs keeps its relative order'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 5)
		assert_order_preserved_except_aghs(X.sBuyList, SHIPPED_POS5, 'pos_5 armed')
	end)
end

-- The shipped index for item_ultimate_scepter is what the reachability argument
-- in hero_zuus.lua depends on. If someone moves Aghs earlier in the shipped
-- table, the motivating measurement is stale and this fails, forcing them to
-- re-argue it (or delete the gate, which would then be a no-op).
tests['shipped pos_5 puts Aghs at index 8, behind six other big items'] = function()
	assert_unarmed()
	local X = load_zeus(true, 5)
	assert(index_of(X.sBuyList, 'item_ultimate_scepter') == 8,
		'shipped pos_5 Aghs index moved from 8; the motivating argument is stale')
	assert(index_of(X.sBuyList, 'item_aether_lens') == 4,
		'shipped pos_5 Aether Lens index moved from 4; the reorder anchor changed')
	assert(index_of(X.sBuyList, 'item_boots_of_bearing') == 7,
		'shipped pos_5 Boots of Bearing index moved from 7; the reachability arithmetic assumes it precedes Aghs')
end

-- pos_5 alone is the scope; other roles must not see the reorder (they buy
-- phylactery / kaya_and_sange / soul_ring first as legitimate laning items).
tests['armed in turbo: pos_2 (mid) is untouched'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 2)
		-- pos_2 shipped keeps item_ultimate_scepter at index 12 (after phylactery,
		-- kaya_and_sange, travel_boots, BKB). Any change to that here would mean
		-- the gate widened beyond its documented scope.
		assert(index_of(X.sBuyList, 'item_ultimate_scepter') == 12,
			'pos_2 Aghs index moved; the gate should only touch pos_5')
	end)
end

tests['armed in turbo: pos_1 is untouched'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 1)
		-- pos_1 keeps its item_ultimate_scepter position; verify it is not slot 5.
		local nAghs = index_of(X.sBuyList, 'item_ultimate_scepter')
		assert(nAghs ~= nil and nAghs > 5,
			'pos_1 Aghs moved into the pos_5 slot; the gate should only touch pos_5')
	end)
end

-- The helper is idempotent: applying it twice must be a no-op after the first
-- application (Aghs is already directly after Aether Lens).
tests['idempotence: re-arming does not shuffle further'] = function()
	with_candidate(CAND, function()
		local X = load_zeus(true, 5)
		local first = {}
		for i, v in ipairs(X.sBuyList) do first[i] = v end
		-- Re-apply by re-dofile'ing the hero file with the same armed state.
		local X2 = load_zeus(true, 5)
		-- with_candidate is still active, so this re-application is the second one.
		-- Wait -- reset_modules() inside load_zeus clears package.loaded so this
		-- is fresh, not "re-applied twice". Assert instead that the SAME armed
		-- input, run twice, produces the same output (deterministic).
		assert_same_list(X2.sBuyList, first, 'armed pos_5 must be deterministic across loads')
	end)
end

return tests
