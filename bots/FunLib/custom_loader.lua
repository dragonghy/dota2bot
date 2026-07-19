local Customize = nil

-- Dev-only soak-farm drafting. Customize/soak_pool.lua exists ONLY on farm
-- instances (gitignored, never shipped): a flat list of internal hero names.
-- Each team scope derives the FULL draft (both teams' picks) from one seed,
-- via a local Park-Miller LCG (double-safe in Lua 5.1):
--   * If the team scopes share a Lua VM, the first scope stashes its seed in
--     _G and the second reuses it — both compute identical partitions and
--     samples, so cross-team duplicate picks are impossible.
--   * If the scopes are isolated VMs, seeds differ and the partitions can
--     disagree — a duplicated pick degrades to OHA's random-available
--     fallback at selection time; occasional, harmless noise.
-- Seeding constraints learned from farm data (iteration 0001): RealTime() is
-- elapsed-since-process-start (NOT wall clock), so any coarse bucket of it is
-- identical every launch; and engine RandomInt() repeats the same sequence at
-- file-load time in the first-loaded scope (radiant drafted the same 5 heroes
-- 18/18 games). The reliable per-launch entropy at load time is the
-- sub-second load-timing jitter in RealTime(), so that drives the seed, with
-- RandomInt mixed in as a secondary source only.
-- Without the pool file this is a silent no-op.
local function ApplySoakDraft( tCustomize )
	local bOk, tPool = pcall( dofile, GetScriptDirectory()..'/Customize/soak_pool' )
	if not bOk or type( tPool ) ~= 'table' or #tPool < 10 then return end

	local tG = type( _G ) == 'table' and _G or nil
	local nSeed = tG and rawget( tG, '__SOAK_DRAFT_SEED' )
	if not nSeed then
		-- Mirrored-draft A/B: soak_side.lua may pin an explicit integer `seed`.
		-- Both team VMs read the same file, so they derive the IDENTICAL draft.
		-- Running one wave with the fix on radiant and a second wave with the
		-- SAME seed but the fix on dire yields two games with an identical draft;
		-- averaging the paired (fix-side − base-side) diff then cancels BOTH the
		-- radiant side bias AND the draft difference, leaving only the fix effect
		-- (the random-draft A/B can't do this — its ±600 GPM/game draft variance
		-- swamps a behavior fix; see iterations/0010). Only active when a positive
		-- seed is set; the normal farm (no seed) keeps the per-launch random draft.
		local bOk, sv = pcall( dofile, GetScriptDirectory()..'/Customize/soak_side' )
		if bOk and type( sv ) == 'table' and type( sv.seed ) == 'number' and sv.seed >= 1 then
			nSeed = math.floor( sv.seed ) % 2147483646 + 1
		else
			nSeed = ( math.floor( ( RealTime() % 1 ) * 1e6 ) * 31
				+ math.floor( RealTime() ) * 7
				+ RandomInt( 1, 1048576 ) ) % 2147483646 + 1
		end
		if tG then rawset( tG, '__SOAK_DRAFT_SEED', nSeed ) end
	end

	local s = nSeed
	local function NextRand( n )
		s = ( s * 16807 ) % 2147483647
		return ( s % n ) + 1
	end

	-- Per-position draft: each team's slots map to positions 1..5 (see
	-- FunLib/aba_role RoleAssignment), and every position is filled only from
	-- heroes ELIGIBLE for that position (pool entry .pos list). This puts each
	-- hero on a lane it can actually play (axe->3, nevermore->2, ...) instead
	-- of the old core/support split that let a pos-3 hero land in the pos-1
	-- slot. Both team VMs share the seed, so they compute the identical 10-hero
	-- assignment and never collide. Accepts the new {name, pos={...}} format;
	-- legacy {name, role}/flat-string entries fall back to any-position.
	local tByPos = { {}, {}, {}, {}, {} }
	for i = 1, #tPool do
		local e = tPool[i]
		local name = type( e ) == 'table' and e.name or e
		local pos = type( e ) == 'table' and type( e.pos ) == 'table' and e.pos or { 1, 2, 3, 4, 5 }
		for _, p in ipairs( pos ) do
			if p >= 1 and p <= 5 then tByPos[p][#tByPos[p] + 1] = name end
		end
	end

	-- Fill the scarcest positions first (fewest eligible heroes) so greedy
	-- assignment doesn't dead-end. Assign radiant then dire for each position.
	local tPosOrder = { 1, 2, 3, 4, 5 }
	table.sort( tPosOrder, function( a, b ) return #tByPos[a] < #tByPos[b] end )

	local tUsed = {}
	local tRad, tDire = {}, {}
	local function PickFor( p )
		local tCand = {}
		for _, name in ipairs( tByPos[p] ) do
			if not tUsed[name] then tCand[#tCand + 1] = name end
		end
		if #tCand == 0 then                    -- dead-end fallback: any unused hero
			for i = 1, #tPool do
				local e = tPool[i]
				local name = type( e ) == 'table' and e.name or e
				if not tUsed[name] then tCand[#tCand + 1] = name end
			end
		end
		if #tCand == 0 then return nil end
		local pick = tCand[NextRand( #tCand )]
		tUsed[pick] = true
		return pick
	end
	for _, p in ipairs( tPosOrder ) do
		tRad[p] = PickFor( p )
		tDire[p] = PickFor( p )
	end

	local function Comp( t )
		local tOut = {}
		for p = 1, 5 do tOut[p] = 'npc_dota_hero_'..( t[p] or 'axe' ) end
		return tOut
	end
	tCustomize.Radiant_Heros = Comp( tRad )
	tCustomize.Dire_Heros = Comp( tDire )
	print( '[SOAK] per-position draft applied (seed='..nSeed..')' )
end

function LoadCustomize()
	if Customize then return Customize end
	local sDir, tSet = "game/Customize/general", nil
	local status, _ = xpcall(function() tSet = require( sDir ) end, function( err ) print( '[WARN] When loading customized file: '..err ) end )
	if status and tSet then
		Customize = tSet
	else
		if GetScriptDirectory() == 'bots' then Customize = require('bots.Customize.general')
		else Customize = require( GetScriptDirectory()..'/Customize/general' ) end
	end
	ApplySoakDraft( Customize )
	return Customize
end
return LoadCustomize()
