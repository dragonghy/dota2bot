-- [hero, `aetherlens`] Aether Lens's cast-range bonus: the shipped constant is
-- 25 units bigger than the item grants.
--
-- GROUND TRUTH, read 2026-09-03 off the mirror this repo already trusts for item
-- data (tools/agent/item_name_census.py takes item NAMES from the same file):
--
--     https://raw.githubusercontent.com/dotabuff/d2vpkr/master/
--         dota/scripts/npc/items.txt
--     "item_aether_lens" / "AbilityValues" / "cast_range_bonus"   "225"
--     (same tree: dota/steam.inf VersionDate = Sep 02 2026, ClientVersion 6921)
--
-- WHY NOBODY CAUGHT IT.  tools/agent/special_value_key_census.py proves reads
-- against the OWNING HERO's KV file, and every hero KV it can fetch is
-- npc_dota_hero_*.txt.  `cast_range_bonus` lives in items.txt, so the constant
-- was outside every census this repo owns -- it is not that a check was skipped,
-- it is that no check could reach it.  This file is that check.
--
-- THE SPLIT, and it is the finding: 29 sites write 250, TWO write 225
-- (hero_axe.lua, hero_dazzle.lua).  The two that look like the copy-paste
-- outliers are the correct ones.  Shape said "fix the two"; the domain price
-- says the other 29 are the defect.
--
-- WHAT IT COSTS.  Every consumer is `abilityX:GetCastRange() + aetherRange` fed
-- to an in-range test or to J.GetCastLocation.  An out-of-range unit-target
-- order does not waste the cast -- the engine walks the hero into range first --
-- so the 25 buys an unplanned approach toward the target on exactly the frames
-- the decision layer thought it could act from where it stood.  The fix is a
-- NARROWING; it can only ever withdraw an order, never invent one.
--
-- LIMIT, DECLARED, and it is structural -- no replay fixture can watch this
-- fire.  The offline frame world answers 0 for every GetSpecialValue key, so the
-- armed leg falls through to shipped on every pinned frame.  This is the same
-- wall tests/test_lion_r_splash_radius_key.lua records for `lionsplash` (GH
-- #162), and it is why sections 2-5 below drive the lever through a DECLARED
-- item stub rather than through a frame.  A stub is weaker evidence than a
-- frame and is labelled as such; what it is NOT weaker than is a fixture that
-- structurally cannot reach the branch.
--
-- SCOPE THIS ROUND: two call sites, both focus heroes with live consumers --
-- hero_crystal_maiden.lua (2 consumers) and hero_lion.lua (4).  hero_axe.lua is
-- already 225; hero_zuus.lua and hero_skeleton_king.lua have no live consumer
-- (zuus assigns aetherRange and never reads it -- section 6 pins that, because
-- it is the reason Zeus is exempt, not an oversight).  Turning all 31 sites at
-- once is the `lanefix` bundle shape and that bundle was rejected twice; the
-- remainder rides section 7's registered reading instead of a promise.

package.path = 'tests/?.lua;' .. package.path
local api  = require('mock.bot_api')
local ss   = require('mock.soak_side')        -- owns bots/Customize/soak_side.lua
local scan = require('lua_source_scan')

local CAND = 'aetherlens'

-- The KV number this round read, frozen so a patch that moves it shows up as a
-- named failure here instead of as silent drift in a comment.
local KV_CAST_RANGE_BONUS = 225

-- The constant the two routed call sites hand the helper.  Not restated prose:
-- section 6 reads it back out of the source and compares.
local SHIPPED_BONUS = 250

local CM   = 'bots/BotLib/hero_crystal_maiden.lua'
local LION = 'bots/BotLib/hero_lion.lua'
local AXE  = 'bots/BotLib/hero_axe.lua'
local ZUUS = 'bots/BotLib/hero_zuus.lua'

local tests = {}

----------------------------------------------------------------------
-- switch hygiene (GH #417 / GH #365 §3): the inherited-leftover guard has
-- to run at FILE LOAD, the only moment that sees the state this process
-- started in.  with_candidate ends by removing the switch, and an armed
-- case can sort before an unarmed one.
----------------------------------------------------------------------

ss.assert_clean('test_aether_lens_range_bonus')

local function with_candidate(sId, fn)
	ss.with_candidate(sId, fn)
end

----------------------------------------------------------------------
-- the subject
----------------------------------------------------------------------

--- A declared Aether Lens stub.  `nKv` is what the item's own
--- GetSpecialValueInt('cast_range_bonus') answers; the key name is checked, so a
--- helper that read some OTHER key would fail here rather than quietly agree.
local function lens(nKv)
	local seen = {}
	local item = api.MakeUnit({
		GetSpecialValueInt = function(_, sKey)
			seen[sKey] = (seen[sKey] or 0) + 1
			if sKey == 'cast_range_bonus' then return nKv end
			return 0
		end,
	})
	return item, seen
end

--- Load J with the mock installed and the game mode set.  reset_modules() first,
--- because the gate's side-file read is cached in a module-level table
--- (jmz_func's tSoakSideCache) -- a stale module would answer for the previous
--- case's switch state.
local function load_J(bTurbo)
	api.reset_modules()
	local bot = api.MakeHero('npc_dota_hero_lion', { CanBeSeen = true })
	bot.GetTeam = function() return TEAM_RADIANT end
	api.install({ bot = bot })
	GetTeam = function() return TEAM_RADIANT end
	if bTurbo == false then
		GetGameMode = function() return 1 end
	else
		GetGameMode = function() return GAMEMODE_TURBO end
	end
	return require(GetScriptDirectory() .. '/FunLib/jmz_func')
end

local function read_file(path)
	local fh = assert(io.open(path, 'r'), 'cannot open ' .. path)
	local s = fh:read('*a')
	fh:close()
	return s
end

----------------------------------------------------------------------
-- 1. gate off is the shipped constant, and it is not an accident of arithmetic
----------------------------------------------------------------------

tests['[gate off] turbo, unarmed: the helper hands back the shipped constant'] = function()
	ss.assert_clean('gate off leg')
	local J = load_J(true)
	local item = lens(KV_CAST_RANGE_BONUS)
	assert(J.GetAetherLensRangeBonus(item, SHIPPED_BONUS) == SHIPPED_BONUS,
		'unarmed must be the shipped constant, got '
		.. tostring(J.GetAetherLensRangeBonus(item, SHIPPED_BONUS)))
end

tests['[gate off] unarmed never reads the KV key at all'] = function()
	ss.assert_clean('gate off leg')
	local J = load_J(true)
	local item, seen = lens(KV_CAST_RANGE_BONUS)
	J.GetAetherLensRangeBonus(item, SHIPPED_BONUS)
	assert(seen['cast_range_bonus'] == nil,
		'gate off must not even reach the read; saw '
		.. tostring(seen['cast_range_bonus']) .. ' call(s)')
end

tests['[gate off] a nil item is the shipped constant, armed or not'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		assert(J.GetAetherLensRangeBonus(nil, SHIPPED_BONUS) == SHIPPED_BONUS,
			'a nil item handle must not change the number')
	end)
end

----------------------------------------------------------------------
-- 2. armed in turbo: the KV number, read off the item's own handle
----------------------------------------------------------------------

tests['[lever] armed in turbo: the bonus becomes the KV 225'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		local item, seen = lens(KV_CAST_RANGE_BONUS)
		local got = J.GetAetherLensRangeBonus(item, SHIPPED_BONUS)
		assert(got == KV_CAST_RANGE_BONUS,
			'armed must be the KV bonus ' .. KV_CAST_RANGE_BONUS
			.. '; got ' .. tostring(got))
		assert(seen['cast_range_bonus'] == 1,
			'the number must come from the item handle, not a re-hardcode; reads='
			.. tostring(seen['cast_range_bonus']))
	end)
end

tests['[lever] the withdrawal is exactly 25 units'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		local item = lens(KV_CAST_RANGE_BONUS)
		assert(SHIPPED_BONUS - J.GetAetherLensRangeBonus(item, SHIPPED_BONUS) == 25,
			'the shipped constant over-states the item by 25 units')
	end)
end

----------------------------------------------------------------------
-- 3. turbo-only
----------------------------------------------------------------------

tests['[lever] armed in NORMAL mode leaves the shipped constant'] = function()
	with_candidate(CAND, function()
		local J = load_J(false)
		assert(J.GetAetherLensRangeBonus(lens(KV_CAST_RANGE_BONUS), SHIPPED_BONUS)
			== SHIPPED_BONUS, 'the gate is turbo-only')
	end)
end

tests['[lever] a different armed candidate leaves the shipped constant'] = function()
	with_candidate('zeusaghs5', function()
		local J = load_J(true)
		-- Positive control INSIDE the case that certifies it (GH #417 §3): a
		-- guard whose subject is destroyed before it looks is prose.  Arming
		-- the real id here, in the same process, must move the number.
		assert(J.GetAetherLensRangeBonus(lens(KV_CAST_RANGE_BONUS), SHIPPED_BONUS)
			== SHIPPED_BONUS, 'another candidate must not arm this gate')
	end)
	with_candidate(CAND, function()
		local J = load_J(true)
		assert(J.GetAetherLensRangeBonus(lens(KV_CAST_RANGE_BONUS), SHIPPED_BONUS)
			== KV_CAST_RANGE_BONUS,
			'positive control: the real id, same file, must fire')
	end)
end

----------------------------------------------------------------------
-- 4. one-directional by construction, and the GH #162 fall-through
----------------------------------------------------------------------

tests['[shape] armed can never claim MORE reach than shipped'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		for _, nKv in ipairs({ 251, 300, 400, 1000 }) do
			local got = J.GetAetherLensRangeBonus(lens(nKv), SHIPPED_BONUS)
			assert(got == SHIPPED_BONUS,
				'a KV bonus of ' .. nKv .. ' must not widen past the shipped '
				.. SHIPPED_BONUS .. '; got ' .. tostring(got))
		end
		assert(J.GetAetherLensRangeBonus(lens(SHIPPED_BONUS), SHIPPED_BONUS)
			== SHIPPED_BONUS, 'equal is not below; shipped wins')
	end)
end

tests['[shape] a renamed key (0) falls through to shipped, not to 0 range'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		for _, nKv in ipairs({ 0, -1 }) do
			local got = J.GetAetherLensRangeBonus(lens(nKv), SHIPPED_BONUS)
			assert(got == SHIPPED_BONUS,
				'a key answering ' .. nKv .. ' must fall through to shipped (GH #162), got '
				.. tostring(got))
		end
	end)
end

tests['[shape] a 225 caller is a no-op by arithmetic, not by exemption'] = function()
	with_candidate(CAND, function()
		local J = load_J(true)
		-- This is what routing hero_axe.lua / hero_dazzle.lua through the helper
		-- would do: they already pass the KV number, so `nKv < nShipped` is false
		-- and they keep it.  Pinned now so the remainder can be routed later
		-- without re-deriving that it is safe.
		assert(J.GetAetherLensRangeBonus(lens(KV_CAST_RANGE_BONUS), KV_CAST_RANGE_BONUS)
			== KV_CAST_RANGE_BONUS, 'a correct caller must not be moved')
	end)
end

----------------------------------------------------------------------
-- 5. the two routed call sites really are routed (source level)
----------------------------------------------------------------------

--- Every `aetherRange = <literal>` assignment in a file, as numbers.
---
--- The `%f[%D]` frontier is load-bearing, not decoration.  The first version of
--- this anchored on `%s*$` and read ZERO bonuses tree-wide, because every site
--- in the tree is written `if aether ~= nil then aetherRange = 250 end` -- the
--- literal is mid-line.  An empty census passes a `<=` ceiling silently, so that
--- version was a green that proved nothing; it was the ceiling's SIBLING
--- assertions (`nOk >= 2`, and the generic file's `== 1`) that spoke up.  A
--- ratchet with no positive-supply assertion beside it cannot tell "nothing is
--- broken" from "nothing was scanned".
local function literal_assignments(path)
	local out = {}
	for _, line in ipairs(scan.stripped_lines(path)) do
		for n in line:gmatch('aetherRange%s*=%s*(%-?%d+)%f[%D]') do
			out[#out + 1] = tonumber(n)
		end
	end
	return out
end

local function routes_through_helper(path)
	local n = 0
	for _, line in ipairs(scan.stripped_lines(path)) do
		if line:match('aetherRange%s*=%s*J%.GetAetherLensRangeBonus%s*%(') then
			n = n + 1
		end
	end
	return n
end

tests['[site] Crystal Maiden and Lion route the aether bonus through the helper'] = function()
	for _, path in ipairs({ CM, LION }) do
		assert(routes_through_helper(path) == 1,
			path .. ' must have exactly one routed assignment, found '
			.. routes_through_helper(path))
		-- The only literal left is the `aetherRange = 0` reset at the top of
		-- SkillsComplement.  A second literal here means someone re-introduced a
		-- hand-written bonus beside the routed one.
		for _, n in ipairs(literal_assignments(path)) do
			assert(n == 0,
				path .. ' still writes a literal aether bonus (' .. n
				.. '); the routed helper is then not the only source')
		end
	end
end

tests['[site] the routed sites hand over the shipped 250, read from source'] = function()
	for _, path in ipairs({ CM, LION }) do
		local n = read_file(path):match(
			'aetherRange%s*=%s*J%.GetAetherLensRangeBonus%s*%(%s*aether%s*,%s*(%d+)%s*%)')
		assert(tonumber(n) == SHIPPED_BONUS,
			path .. ' hands the helper ' .. tostring(n) .. ', not the shipped '
			.. SHIPPED_BONUS .. ' this file reasons about')
	end
end

----------------------------------------------------------------------
-- 6. why the other three focus heroes are NOT in scope -- pinned, so the
--    exemption cannot later be read as an oversight
----------------------------------------------------------------------

tests['[scope] Axe already carries the KV number and is left alone'] = function()
	local lits = literal_assignments(AXE)
	local nBonus = 0
	for _, n in ipairs(lits) do if n ~= 0 then nBonus = nBonus + 1
		assert(n == KV_CAST_RANGE_BONUS,
			'hero_axe.lua writes ' .. n .. '; it was the correct 225 when this '
			.. 'round exempted it') end end
	assert(nBonus == 1, 'hero_axe.lua should carry exactly one aether bonus literal')
	assert(routes_through_helper(AXE) == 0, 'Axe is deliberately not routed')
end

tests['[scope] Zeus assigns the aether bonus and never reads it'] = function()
	local nConsumers = 0
	for _, line in ipairs(scan.stripped_lines(ZUUS)) do
		if line:find('aetherRange', 1, true)
			and not line:match('aetherRange%s*=') then
			nConsumers = nConsumers + 1
		end
	end
	assert(nConsumers == 0,
		'hero_zuus.lua grew a consumer of aetherRange (' .. nConsumers
		.. '); the "no live consumer" exemption this round took is now stale')
end

----------------------------------------------------------------------
-- 7. the untouched remainder, as a REGISTERED READING with a direction
----------------------------------------------------------------------

--- The whole tree, counted the way the finding was counted.
local function census()
	local nOver, nOk, nOther, files = 0, 0, 0, {}
	for _, path in ipairs(scan.bots_files()) do
		for _, n in ipairs(literal_assignments(path)) do
			if n == 0 then                       -- the per-frame reset, not a bonus
			elseif n > KV_CAST_RANGE_BONUS then
				nOver = nOver + 1
				files[#files + 1] = path .. '=' .. n
			elseif n == KV_CAST_RANGE_BONUS then
				nOk = nOk + 1
			else
				nOther = nOther + 1
			end
		end
	end
	return nOver, nOk, nOther, files
end

-- Read on 2026-09-03, AFTER this round routed Crystal Maiden and Lion.  The
-- ceiling is a RATCHET, not an equality: fixing more sites drives it DOWN, and
-- that must not be a failure (GH #457 -- two censuses froze `==` on a number
-- that was always going to move, and the team's own routine landings pushed
-- trunk red inside 14 hours).  Growth IS a finding: a new hero file copying the
-- 250 is precisely what this reading exists to catch.
local OVERSTATED_CEILING = 27

tests['[census] no NEW site may over-state the Aether Lens bonus'] = function()
	local nOver, nOk, nOther, files = census()
	assert(nOver <= OVERSTATED_CEILING, string.format(
		'sites writing a bonus above the KV %d: %d (ceiling %d). '
		.. 'If this grew, a new site copied the stale constant: %s',
		KV_CAST_RANGE_BONUS, nOver, OVERSTATED_CEILING, table.concat(files, ' ')))
	-- Registered alongside, because the split is the finding and a bare ceiling
	-- would not carry it: `nOk` counts the sites that already agree with the KV.
	assert(nOk >= 2, 'the KV-correct sites (axe, dazzle) disappeared; nOk=' .. nOk)
	assert(nOther >= 0, 'placeholder for sub-225 literals; today: ' .. nOther)
end

tests['[census] the shared generic file is still the biggest untouched carrier'] = function()
	local path = 'bots/ability_item_usage_generic.lua'
	local nBonus = 0
	for _, n in ipairs(literal_assignments(path)) do
		if n ~= 0 then nBonus = nBonus + 1 end
	end
	-- One literal, 42 consumers, every one of the 128 shipped heroes downstream.
	-- It is NOT routed this round on purpose (see the SCOPE block above the
	-- helper); this case exists so "not routed" stays a decision with a name
	-- rather than a thing nobody is counting.
	assert(nBonus == 1, path .. ' now writes ' .. nBonus
		.. ' aether bonus literals; the handoff registered in the round report '
		.. 'assumed exactly one')
end

return tests
