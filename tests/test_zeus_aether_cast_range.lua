-- [hero, `zusaether`] Zeus computes the Aether Lens cast-range bonus and then
-- throws it away.
--
-- THE DEFECT.  bots/BotLib/hero_zuus.lua is a HALF-WIRED copy of the BotLib
-- Aether Lens template.  The producer is present -- `aetherRange` is declared,
-- reset at the top of X.SkillsComplement, and set under an
-- `IsItemAvailable('item_aether_lens')` test -- but all three cast-range
-- consumers dropped the `+ aetherRange` term the template carries.  X.ConsiderQ,
-- X.ConsiderW and X.ConsiderW2 each read a bare `abilityX:GetCastRange()`.
--
-- THE DOMAIN IS LIVE, not a dead branch.  `sRoleItemsBuyList` buys
-- item_aether_lens on BOTH support rows this hero plays (pos_4 and pos_5), and
-- the `zeusaghs5` candidate reasons about that very purchase order.  A support
-- Zeus that follows its own buy list ends the game holding the item whose
-- bonus this file discards.
--
-- THE CENSUS THAT MAKES IT A CLASS RATHER THAN A TYPO.  Read 2026-09-04 over
-- the whole tree: 33 files under bots/ declare `aetherRange`; 26 wire it into
-- at least one cast-range read; 7 compute it and read it NOWHERE.  Before this
-- round Zeus was the 8th, and it is the only focus hero in that set.  Section 5
-- pins the count as a ratchet.
--
-- THE DIRECTION IS THE OPPOSITE OF GH #459's, and that is the whole reason this
-- is worth a gate.  In all three consumers `nCastRange` is the radius of the
-- hero's own SEARCH ring:
--
--     X.ConsiderQ    J.GetNearbyHeroes(bot, nCastRange, true, ...)
--     X.ConsiderW    J.IsInRange(target, bot, nCastRange)
--                    J.GetVulnerableWeakestUnit(bot, true, true, nCastRange)
--     X.ConsiderW2   J.GetNearbyHeroes(bot, nCastRange + nRadius, ...)
--                    bot:FindAoELocation(..., nCastRange, ...)
--                    J.GetCastLocation(bot, target, nCastRange, nRadius)
--
-- GH #459 measured an OVER-stated bonus, whose cost is an unplanned approach:
-- the decision layer believes it can act from where it stands, issues the order,
-- and the engine walks the hero forward.  UNDER-stating is a different failure
-- with a different sign.  It does not order any movement at all; it makes an
-- enemy who is genuinely inside the item's extended cast range INVISIBLE to the
-- decision.  Concretely, with the lens bought, ConsiderQ's execute loop
-- (`J.GetHP(npcEnemy) <= 0.2`) cannot see a killable target between 900 and
-- 1150 units, and ConsiderW declines to Bolt a target it could in fact hit.
-- Restoring the term can only ever ADD a cast the hero already paid gold for.
-- It cannot invent reach the item does not grant (section 4).
--
-- WHAT THE FRAMES DO AND DO NOT SHOW -- stated up front because the honest
-- reading here is narrower than the mechanism.  On both real frames below the
-- ring provably widens and the armed leg reaches strictly more code, but the
-- FINAL desire is 0 on both legs of both frames: this round did not catch a
-- flipped outcome, it caught a flipped domain.  Section 3 registers that as a
-- reading rather than leaving it as a silence.
--
-- THE ONE DECLARED ANCHOR, and it is measured, not assumed: 0 of the 109
-- fixtures under tests/fixtures/ carry an Aether Lens (counted 2026-09-04;
-- section 3 re-counts it here so the number cannot drift in prose).  The item
-- is therefore DECLARED onto an otherwise untouched real frame, in the same
-- spirit as the cast-range anchors tests/test_replay_260819_zuus_w2_leak.lua
-- declares for the same hero.  It displaces exactly one inert main slot and the
-- displaced item is pinned by name, so the anchor stays auditable.  Everything
-- the branches actually read -- every hero's position, HP, alive/dead, Zeus's
-- mana, ability levels and cooldowns -- is real frame data.
--
-- INDEPENDENT OF 'aetherlens' ON PURPOSE.  hero_zuus.lua's producer is now
-- routed through J.GetAetherLensRangeBonus so that lever can correct the
-- inherited 250 to the live KV 225, but the two ids are never conjoined.  A
-- gate written `IsSoakCandidate('A') and IsSoakCandidate('B')` freezes FALSE
-- the day either id is promoted -- the `pullcad` trap in AGENTS.md.  Section 2
-- drives all four combinations to keep that isolable.

package.path = 'tests/?.lua;' .. package.path
local rf  = require('mock.replay_fixture')
local api = require('mock.bot_api')
local scan = require('lua_source_scan')

local CAND      = 'zusaether'
local LENS_CAND = 'aetherlens'

local ZUUS = 'bots/BotLib/hero_zuus.lua'

-- External anchors.  make_fixture.py extracts no ability specs, so the dumper
-- reports 0 for both of these; without them no cast-range branch is reachable
-- and every case in this file would be a false green.  Liquipedia, 7.41:
local ARC_RANGE  = 900          -- zuus_arc_lightning
local BOLT_RANGE = 700          -- zuus_lightning_bolt
local W2_SPREAD  = 325          -- zuus_lightning_bolt/AbilityValues/spread_aoe,
                                -- already verified against the KV in hero_zuus.lua

-- The constant hero_zuus.lua hands the 'aetherlens' helper, and the live KV that
-- helper substitutes when ITS id is armed (GH #459 ground truth).
local SHIPPED_BONUS = 250
local KV_BONUS      = 225

-- The two frames, and the band each one exercises.
local FRAME_Q  = 'tests/fixtures/f_260820_042607_zuus_reserve_safe.lua'
local FRAME_W2 = 'tests/fixtures/f_260819_222052_zuus_w2_leak.lua'

-- The main slot the declared lens displaces, and what really sits there.  Both
-- are inert stat/component items that no cast-range branch in this hero reads;
-- pinning them by name is what keeps the anchor auditable rather than a hidden
-- edit to the frame.
local ANCHOR_SLOT = 3
local DISPLACED = {
	[FRAME_Q]  = 'item_ironwood_branch',
	[FRAME_W2] = 'item_sobi_mask',
}

----------------------------------------------------------------------
-- the harness
----------------------------------------------------------------------

--- Load a frame, anchor what the dumper cannot report, optionally declare an
--- Aether Lens into one main slot, and arm the requested candidate ids.
---
--- `tArmed` is a set of ids, so the two levers can be driven in all four
--- combinations without ever writing a conjunction into the subject.
local function load_zeus(sFrame, tArmed, bTurbo, bLens)
	local J, bot, heroes, fx = rf.load(sFrame)

	rawget(bot:GetAbilityByName('zuus_arc_lightning'),  '__spec').GetCastRange = ARC_RANGE
	rawget(bot:GetAbilityByName('zuus_lightning_bolt'), '__spec').GetCastRange = BOLT_RANGE

	if bLens ~= false then
		local sWas = bot:GetItemInSlot(ANCHOR_SLOT)
		sWas = sWas and sWas:GetName() or 'nil'
		assert(sWas == DISPLACED[sFrame], string.format(
			'the declared anchor displaces slot %d, which this frame carried as %s '
			.. 'when the anchor was chosen; it now carries %s. Re-read the frame '
			.. 'before trusting any case in this file.',
			ANCHOR_SLOT, tostring(DISPLACED[sFrame]), sWas))

		local lens = api.MakeAbility('item_aether_lens', {
			IsFullyCastable = true,
			-- The helper reads this key only when 'aetherlens' is armed.
			GetSpecialValueInt = function(_, sKey)
				if sKey == 'cast_range_bonus' then return KV_BONUS end
				return 0
			end,
		})
		local fFind, fGet = bot.FindItemSlot, bot.GetItemInSlot
		bot.FindItemSlot = function(s, sName)
			if sName == 'item_aether_lens' then return ANCHOR_SLOT end
			return fFind(s, sName)
		end
		bot.GetItemInSlot = function(s, i)
			if i == ANCHOR_SLOT then return lens end
			return fGet(s, i)
		end
	end

	if bTurbo == false then
		GetGameMode = function() return GAMEMODE_ALLPICK end
	end

	J.IsSoakCandidate = function(sId) return tArmed[sId] == true end

	local X = rf.load_hero('zuus')
	return X, J, bot, heroes, fx
end

--- Every radius handed to the ring builders during one Consider* call.
---
--- This is the positive control, and it is the reason a "no decision changed"
--- reading below is a measurement rather than a silence: without it, "the armed
--- leg produced the same desire" and "the armed leg never executed the branch at
--- all" look exactly alike.  Same instrument GH #407 needed for X.ConsiderQ.
local function radii_of(X, J, fConsider)
	local out = {}
	local fNear, fIn, fWeak = J.GetNearbyHeroes, J.IsInRange, J.GetVulnerableWeakestUnit
	J.GetNearbyHeroes = function(b, r, e, m) out[#out + 1] = r; return fNear(b, r, e, m) end
	J.IsInRange = function(a, b, r) out[#out + 1] = r; return fIn(a, b, r) end
	J.GetVulnerableWeakestUnit = function(b, p, q, r)
		out[#out + 1] = r; return fWeak(b, p, q, r)
	end
	local ok, err = pcall(fConsider, X)
	J.GetNearbyHeroes, J.IsInRange, J.GetVulnerableWeakestUnit = fNear, fIn, fWeak
	assert(ok, 'the Consider call itself failed: ' .. tostring(err))
	return out
end

local function has(t, v)
	for _, x in ipairs(t) do if x == v then return true end end
	return false
end

--- Run X.SkillsComplement first: `aetherRange` is set there, and a Consider
--- driven without it would read the file-local's initial 0 and pass vacuously.
local function primed(sFrame, tArmed, bTurbo, bLens)
	local X, J, bot, heroes, fx = load_zeus(sFrame, tArmed, bTurbo, bLens)
	X.SkillsComplement()
	return X, J, bot, heroes, fx
end

local ON  = { [CAND] = true }
local OFF = {}

local tests = {}

----------------------------------------------------------------------
-- 1. ground truth: the two frames really do straddle the two bands
----------------------------------------------------------------------

tests['[ground truth] an enemy sits between Arc Lightning and Arc + lens'] = function()
	local _, _, bot, heroes = primed(FRAME_Q, OFF)
	local drow = heroes['npc_dota_hero_drow_ranger']
	assert(drow ~= nil and drow:IsAlive(), 'the frame carries a living drow_ranger')
	local d = GetUnitToUnitDistance(bot, drow)
	assert(d > ARC_RANGE and d < ARC_RANGE + KV_BONUS, string.format(
		'the whole point of this frame is that drow_ranger stands OUTSIDE %d and '
		.. 'INSIDE %d; measured %.0f', ARC_RANGE, ARC_RANGE + KV_BONUS, d))
	-- Registered, not asserted as a kill: at 47%% HP she is not inside
	-- ConsiderQ's `<= 0.2` execute window.  What this frame demonstrates is the
	-- domain, and section 3 says so out loud.
	assert(drow:GetHealth() / drow:GetMaxHealth() > 0.2,
		'this frame is a domain demonstration, not a missed execute')
end

tests['[ground truth] an enemy sits between Lightning Bolt and Bolt + lens'] = function()
	local _, _, bot, heroes = primed(FRAME_W2, OFF)
	local cent = heroes['npc_dota_hero_centaur']
	assert(cent ~= nil and cent:IsAlive(), 'the frame carries a living centaur')
	local d = GetUnitToUnitDistance(bot, cent)
	assert(d > BOLT_RANGE and d < BOLT_RANGE + KV_BONUS, string.format(
		'centaur must stand OUTSIDE %d and INSIDE %d; measured %.0f',
		BOLT_RANGE, BOLT_RANGE + KV_BONUS, d))
end

----------------------------------------------------------------------
-- 2. the lever, on the real frames, and the four gate combinations
----------------------------------------------------------------------

tests['[gate off] unarmed, ConsiderQ searches exactly the shipped cast range'] = function()
	for _, sFrame in ipairs({ FRAME_Q, FRAME_W2 }) do
		local X, J = primed(sFrame, OFF)
		local r = radii_of(X, J, X.ConsiderQ)
		assert(has(r, ARC_RANGE), sFrame .. ': unarmed must search the bare '
			.. ARC_RANGE .. '; saw [' .. table.concat(r, ',') .. ']')
		assert(not has(r, ARC_RANGE + SHIPPED_BONUS),
			sFrame .. ': unarmed must not widen the ring')
	end
end

tests['[lever] armed in turbo, ConsiderQ searches cast range + the lens'] = function()
	for _, sFrame in ipairs({ FRAME_Q, FRAME_W2 }) do
		local X, J = primed(sFrame, ON)
		local r = radii_of(X, J, X.ConsiderQ)
		assert(has(r, ARC_RANGE + SHIPPED_BONUS), string.format(
			'%s: armed must search %d; saw [%s]',
			sFrame, ARC_RANGE + SHIPPED_BONUS, table.concat(r, ',')))
		assert(not has(r, ARC_RANGE),
			sFrame .. ': the widened ring REPLACES the bare one, it is not an extra pass')
	end
end

tests['[lever] armed in turbo, ConsiderW2 widens its AoE ring by the lens'] = function()
	for _, sFrame in ipairs({ FRAME_Q, FRAME_W2 }) do
		local Xoff, Joff = primed(sFrame, OFF)
		assert(has(radii_of(Xoff, Joff, Xoff.ConsiderW2), BOLT_RANGE + W2_SPREAD),
			sFrame .. ': unarmed ConsiderW2 rings at ' .. (BOLT_RANGE + W2_SPREAD))
		local Xon, Jon = primed(sFrame, ON)
		assert(has(radii_of(Xon, Jon, Xon.ConsiderW2),
			BOLT_RANGE + SHIPPED_BONUS + W2_SPREAD), string.format(
			'%s: armed ConsiderW2 must ring at %d',
			sFrame, BOLT_RANGE + SHIPPED_BONUS + W2_SPREAD))
	end
end

tests['[lever] the armed leg reaches strictly more of ConsiderQ'] = function()
	-- On FRAME_Q the unarmed ring holds nobody, so the execute loop body never
	-- runs.  Armed, drow_ranger enters it and the function walks further.  This
	-- is the difference the desire alone cannot show (section 3).
	local Xoff, Joff = primed(FRAME_Q, OFF)
	local Xon,  Jon  = primed(FRAME_Q, ON)
	local nOff = #radii_of(Xoff, Joff, Xoff.ConsiderQ)
	local nOn  = #radii_of(Xon,  Jon,  Xon.ConsiderQ)
	assert(nOn > nOff, string.format(
		'armed must execute more of the function, not merely a different number: '
		.. 'unarmed %d ring calls, armed %d', nOff, nOn))
end

tests['[gate off] armed but NOT turbo leaves the shipped ring'] = function()
	local X, J = primed(FRAME_Q, ON, false)
	local r = radii_of(X, J, X.ConsiderQ)
	assert(has(r, ARC_RANGE) and not has(r, ARC_RANGE + SHIPPED_BONUS),
		'the gate is turbo-only; saw [' .. table.concat(r, ',') .. ']')
end

tests['[gate off] a different armed candidate leaves the shipped ring'] = function()
	local X, J = primed(FRAME_Q, { zeusaghs5 = true })
	assert(not has(radii_of(X, J, X.ConsiderQ), ARC_RANGE + SHIPPED_BONUS),
		'another candidate must not arm this gate')
	-- Positive control INSIDE the case that certifies it (GH #417 §3): a guard
	-- whose subject is destroyed before it looks is prose.
	local Xon, Jon = primed(FRAME_Q, ON)
	assert(has(radii_of(Xon, Jon, Xon.ConsiderQ), ARC_RANGE + SHIPPED_BONUS),
		'positive control: the real id, same file, must widen the ring')
end

tests['[gate off] no lens in the inventory is the shipped ring even when armed'] = function()
	local X, J = primed(FRAME_Q, ON, true, false)
	assert(has(radii_of(X, J, X.ConsiderQ), ARC_RANGE),
		'without the item there is no bonus to add, armed or not')
	assert(not has(radii_of(X, J, X.ConsiderQ), ARC_RANGE + SHIPPED_BONUS),
		'the gate must not conjure reach the hero did not buy')
end

tests['[isolation] the two ids are independent, in all four combinations'] = function()
	-- The `pullcad` trap: a conjunction would make this candidate die silently
	-- the day either id is promoted.  Driving all four combinations is what
	-- makes "independent" a reading instead of a comment.
	local function ring(tArmed)
		local X, J = primed(FRAME_Q, tArmed)
		return radii_of(X, J, X.ConsiderQ)
	end
	assert(has(ring({}), ARC_RANGE), 'neither: shipped')
	assert(has(ring({ [LENS_CAND] = true }), ARC_RANGE),
		'aetherlens alone must stay a no-op here -- Zeus had no consumer before '
		.. 'this round, and correcting an unread number changes nothing')
	assert(has(ring(ON), ARC_RANGE + SHIPPED_BONUS),
		'zusaether alone must use the shipped 250')
	assert(has(ring({ [CAND] = true, [LENS_CAND] = true }), ARC_RANGE + KV_BONUS),
		'both armed must use the live KV ' .. KV_BONUS
		.. ' -- the two levers compose, they do not gate each other')
end

----------------------------------------------------------------------
-- 3. the honest limits, REGISTERED as readings so they cannot decay into
--    silence.  Each of these is a number this round measured, not a caveat.
----------------------------------------------------------------------

tests['[limit] no fixture in the corpus carries an Aether Lens'] = function()
	local nTotal, nLens = 0, 0
	local p = assert(io.popen('ls tests/fixtures/*.lua 2>/dev/null'))
	for sPath in p:lines() do
		nTotal = nTotal + 1
		local fh = io.open(sPath, 'r')
		if fh then
			if fh:read('*a'):find('aether_lens', 1, true) then nLens = nLens + 1 end
			fh:close()
		end
	end
	p:close()
	assert(nTotal > 100, 'the corpus should be ~109 fixtures, counted ' .. nTotal)
	assert(nLens == 0, string.format(
		'%d of %d fixtures now carry an Aether Lens. That is GOOD NEWS: the '
		.. 'declared anchor in this file can be replaced by a real inventory. '
		.. 'Do not delete this case -- retarget it.', nLens, nTotal))
end

tests['[limit] X.ConsiderW is NOT reached by either frame'] = function()
	-- Its two cast-range consumers sit behind J.IsRetreating and
	-- J.IsGoingOnSomeone, and neither holds on these frames.  Registered by
	-- name so a later round does not read this file as covering all three
	-- sites.  Section 4 covers that site at source level only.
	for _, sFrame in ipairs({ FRAME_Q, FRAME_W2 }) do
		local X, J = primed(sFrame, ON)
		local r = radii_of(X, J, X.ConsiderW)
		assert(not has(r, BOLT_RANGE + SHIPPED_BONUS) and not has(r, BOLT_RANGE),
			sFrame .. ': ConsiderW became reachable here (saw ['
			.. table.concat(r, ',') .. ']). It now needs a real-frame assertion '
			.. 'of its own rather than this registration.')
	end
end

tests['[limit] neither frame flips the final desire'] = function()
	-- The mechanism is proven above; the OUTCOME is not.  Buying condition (a)
	-- for this candidate needs a wave detector, not another fixture.  Pinned so
	-- that a future round which DOES flip an outcome sees this case go red and
	-- reads it as the good news it is.
	for _, sFrame in ipairs({ FRAME_Q, FRAME_W2 }) do
		local Xoff = primed(sFrame, OFF)
		local Xon  = primed(sFrame, ON)
		assert(Xoff.ConsiderQ() == Xon.ConsiderQ(), sFrame
			.. ': ConsiderQ desire moved. The ring widening now has an outcome on '
			.. 'a pinned frame -- record it in the report and retarget this case.')
	end
end

----------------------------------------------------------------------
-- 4. the three call sites, at source level
----------------------------------------------------------------------

local function zuus_lines()
	return scan.stripped_lines(ZUUS)
end

tests['[site] all three cast-range reads are routed through the gate'] = function()
	local nRouted, nBare = 0, 0
	for _, line in ipairs(zuus_lines()) do
		if line:match('local nCastRange%s*=%s*ability[QW]:GetCastRange%(%)%s*%+%s*AetherReach%(%s*%)') then
			nRouted = nRouted + 1
		elseif line:match('local nCastRange%s*=%s*ability[QW]:GetCastRange%(%)%s*$') then
			nBare = nBare + 1
		end
	end
	assert(nRouted == 3, 'hero_zuus.lua must route exactly 3 cast-range reads, found ' .. nRouted)
	assert(nBare == 0, 'hero_zuus.lua still has ' .. nBare
		.. ' un-routed bare GetCastRange() read(s); the half-wiring is back')
end

tests['[site] the producer is routed through the aetherlens helper'] = function()
	local n = 0
	for _, line in ipairs(zuus_lines()) do
		if line:match('aetherRange%s*=%s*J%.GetAetherLensRangeBonus%s*%(%s*aether%s*,%s*'
			.. SHIPPED_BONUS .. '%s*%)') then n = n + 1 end
	end
	assert(n == 1, 'hero_zuus.lua must hand the helper the shipped ' .. SHIPPED_BONUS
		.. ' exactly once, found ' .. n)
	for _, line in ipairs(zuus_lines()) do
		assert(not line:match('aetherRange%s*=%s*%d%d+'),
			'a hand-written aether bonus literal is back in hero_zuus.lua: ' .. line)
	end
end

tests['[site] the gate is not conjoined with any other candidate id'] = function()
	for _, line in ipairs(zuus_lines()) do
		if line:find("IsSoakCandidate( '" .. CAND .. "'", 1, true) then
			local _, n = line:gsub('IsSoakCandidate', '')
			assert(n == 1, 'the ' .. CAND .. ' gate names another candidate on the '
				.. 'same line; that freezes FALSE on promote (the pullcad trap): ' .. line)
		end
	end
end

----------------------------------------------------------------------
-- 5. the untouched remainder, as a registered reading with a direction
----------------------------------------------------------------------

--- Files that declare `aetherRange`, split by whether anything reads it.
local function wiring_census()
	local nDecl, nWired, nDead, tDead = 0, 0, 0, {}
	for _, sPath in ipairs(scan.bots_files()) do
		local bDecl, nCons = false, 0
		for _, line in ipairs(scan.stripped_lines(sPath)) do
			if line:match('^%s*local%s+aetherRange%s*=') then
				bDecl = true
			elseif line:find('aetherRange', 1, true)
				and not line:match('aetherRange%s*=') then
				nCons = nCons + 1
			end
		end
		if bDecl then
			nDecl = nDecl + 1
			if nCons == 0 then
				nDead = nDead + 1
				tDead[#tDead + 1] = sPath
			else
				nWired = nWired + 1
			end
		end
	end
	return nDecl, nWired, nDead, tDead
end

-- Read 2026-09-04, AFTER this round wired Zeus.  A RATCHET, not an equality:
-- wiring more heroes drives it DOWN and that must not be a failure (GH #457 --
-- two censuses froze `==` on a number that was always going to move and pushed
-- trunk red inside 14 hours).  Growth IS the finding this case exists to catch:
-- it means another hero file grew a producer nobody reads.
local DEAD_PRODUCER_CEILING = 7

tests['[census] no NEW hero may compute the aether bonus and discard it'] = function()
	local nDecl, nWired, nDead, tDead = wiring_census()
	assert(nDead <= DEAD_PRODUCER_CEILING, string.format(
		'files that declare aetherRange and read it nowhere: %d (ceiling %d). '
		.. 'If this grew, a file copied the producer without the consumers: %s',
		nDead, DEAD_PRODUCER_CEILING, table.concat(tDead, ' ')))
	-- The supply assertion beside the ceiling, because a ratchet alone cannot
	-- tell "nothing is broken" from "nothing was scanned" -- the lesson
	-- tests/test_aether_lens_range_bonus.lua paid for with an empty census that
	-- passed a `<=` silently.
	assert(nDecl >= 30, 'the aetherRange population collapsed; nDecl=' .. nDecl)
	assert(nWired >= 26, 'wired files fell below the reading this round took; nWired='
		.. nWired)
end

tests['[census] Zeus is no longer one of the dead producers'] = function()
	local _, _, _, tDead = wiring_census()
	for _, sPath in ipairs(tDead) do
		assert(not sPath:find('hero_zuus', 1, true),
			'hero_zuus.lua is back in the dead-producer set; this round is undone')
	end
end

return tests
