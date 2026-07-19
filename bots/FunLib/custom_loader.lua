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
		nSeed = ( math.floor( ( RealTime() % 1 ) * 1e6 ) * 31
			+ math.floor( RealTime() ) * 7
			+ RandomInt( 1, 1048576 ) ) % 2147483646 + 1
		if tG then rawset( tG, '__SOAK_DRAFT_SEED', nSeed ) end
	end

	local s = nSeed
	local function NextRand( n )
		s = ( s * 16807 ) % 2147483647
		return ( s % n ) + 1
	end
	local tShuffled = {}
	for i = 1, #tPool do tShuffled[i] = tPool[i] end
	for i = #tShuffled, 2, -1 do
		local j = NextRand( i )
		tShuffled[i], tShuffled[j] = tShuffled[j], tShuffled[i]
	end

	local nHalf = math.floor( #tShuffled / 2 )
	local function SampleRange( nFrom, nTo, nCount )
		local tIdx, tOut = {}, {}
		for i = nFrom, nTo do tIdx[#tIdx + 1] = i end
		for _ = 1, nCount do
			local j = NextRand( #tIdx )
			tOut[#tOut + 1] = 'npc_dota_hero_'..tShuffled[tIdx[j]]
			table.remove( tIdx, j )
		end
		return tOut
	end
	tCustomize.Radiant_Heros = SampleRange( 1, nHalf, 5 )
	tCustomize.Dire_Heros = SampleRange( nHalf + 1, #tShuffled, 5 )
	print( '[SOAK] draft applied (pool='..#tShuffled..', seed='..nSeed..')' )
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
